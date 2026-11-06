#include "ff.h"
#include "sleep.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xstatus.h"
#include "xil_types.h"
#include <stdlib.h>
#include <string.h>

#define LLAMA_CTRL_BASE       0x43C00000U
#define LLAMA_TOKEN_OFFSET    0x00000000U
#define LLAMA_RESULT_OFFSET   0x00000004U
#define LLAMA_SCRATCH_OFFSET  0x0000000CU
#define LLAMA_TOTAL_OFFSET    0x00000010U
#define LLAMA_RESULT_ACK      0x00000080U
#define LLAMA_RESET_OFFSET    0x000000C0U
#define TOKEN_TRACE_BASE      0x3FF00000U
#define TOKEN_TRACE_MAGIC     0x52323054U
#define LLAMA_DIAG_CORE0      0x00000028U
#define LLAMA_DIAG_CORE1      0x0000002CU
#define LLAMA_DIAG_AXI0       0x00000030U
#define LLAMA_DIAG_AXI1       0x00000034U
#define LLAMA_DIAG_C2C        0x00000038U
#define LLAMA_DIAG_PIPE0_0    0x00000048U
#define LLAMA_DIAG_PIPE1_0    0x00000054U
#define PS_MODEL_BASE         0x01000000U
#ifdef ZYNQ7035
#define MODEL_IMAGE_BYTES     937803776U
#else
#define PL_MODEL_BASE         0x80000000U
#define MODEL_IMAGE_BYTES     442482688U
#endif
#define LOAD_CHUNK_BYTES      (1024U * 1024U)

#define VOCAB_SIZE            32000
#define VOCAB_STORAGE_BYTES   210000
#define MAX_PROMPT_TOKENS     256
#ifdef ZYNQ7035
#ifndef MAX_DECODE_TOKENS
#define MAX_DECODE_TOKENS     128
#endif
#ifndef CHAT_RAW_DIAGNOSTIC
#define CHAT_RAW_DIAGNOSTIC   0
#endif
#define CHAT_LINE_BYTES       512
#define CHAT_HISTORY_BYTES    4096
#define CHAT_MAX_HISTORY_TURNS 64
#define FPGA_MAX_TOKENS       1024
#if MAX_DECODE_TOKENS < 1 || MAX_PROMPT_TOKENS + MAX_DECODE_TOKENS > FPGA_MAX_TOKENS
#error "Input plus output budget exceeds the Round52 FPGA token capacity"
#endif
#else
#define MAX_DECODE_TOKENS     16
#endif
#define RESULT_TIMEOUT_MS     120000U
#define BOS_TOKEN_ID          1
#define EOS_TOKEN_ID          2

typedef struct {
    char *str;
    int id;
} TokenIndex;

typedef struct {
    char **vocab;
    float *scores;
    TokenIndex *sorted;
    u32 max_token_length;
    unsigned char byte_pieces[512];
} Tokenizer;

static FATFS fatfs;
static FIL data_file;
static u8 io_buffer[LOAD_CHUNK_BYTES] __attribute__((aligned(64)));
static char *vocab[VOCAB_SIZE];
static float vocab_scores[VOCAB_SIZE];
static TokenIndex sorted_vocab[VOCAB_SIZE];
static char vocab_storage[VOCAB_STORAGE_BYTES];
static char token_buffer[128];
static int prompt_tokens[MAX_PROMPT_TOKENS];
#ifdef ZYNQ7035
static char chat_line[CHAT_LINE_BYTES];
static char chat_history[CHAT_HISTORY_BYTES];
static char chat_prompt[CHAT_HISTORY_BYTES];
static char chat_reply[CHAT_HISTORY_BYTES];
static char chat_segment[CHAT_HISTORY_BYTES];
/* BPE first expands text to byte/character tokens, then merges. The working
   capacity must cover the text, independently of the final 256-token limit. */
static int chat_segment_tokens[CHAT_HISTORY_BYTES + 1];
#if !CHAT_RAW_DIAGNOSTIC
static size_t chat_turn_bytes[CHAT_MAX_HISTORY_TURNS];
static int chat_turn_count;
#endif

static int append_text(char *dst, size_t capacity, const char *src)
{
    size_t used = strlen(dst);
    size_t add = strlen(src);
    if (used + add >= capacity) return XST_FAILURE;
    memcpy(dst + used, src, add + 1U);
    return XST_SUCCESS;
}

static void read_chat_line(char *dst, size_t capacity)
{
    size_t used = 0U;
    for (;;) {
        unsigned char ch = (unsigned char)inbyte();
        if (ch == '\r' || ch == '\n') {
            dst[used] = '\0';
            xil_printf("\r\n");
            return;
        }
        if (ch == 8U || ch == 127U) {
            if (used != 0U) {
                --used;
                xil_printf("\b \b");
            }
            continue;
        }
        if (ch >= 32U && used + 1U < capacity) {
            dst[used++] = (char)ch;
            outbyte((char)ch);
        }
    }
}
#endif

static void print_diagnostics(const char *label, u32 elapsed_ms)
{
    u32 core0 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_CORE0);
#ifdef ZYNQ7035
    u32 axi0 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_AXI0);
    u32 p00 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE0_0);
    u32 p01 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE0_0 + 4U);
    u32 p02 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE0_0 + 8U);
    u32 v00 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE1_0);
    u32 v01 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE1_0 + 4U);
    u32 v02 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE1_0 + 8U);

    xil_printf("DIAG %s %lu ms: core0=%08lx axi0=%08lx\r\n",
               label, (unsigned long)elapsed_ms,
               (unsigned long)core0, (unsigned long)axi0);
    xil_printf("  core: bit0 prefill, bits16:1 token, bits24:17 layer; "
               "axi groups[3:0]=ARV [7:4]=ARfire [11:8]=RV [15:12]=RLAST [19:16]=RERR\r\n");
    xil_printf("  pipe0=%08lx/%08lx/%08lx\r\n",
               (unsigned long)p00, (unsigned long)p01, (unsigned long)p02);
    xil_printf("  deep=%08lx/%08lx/%08lx\r\n",
               (unsigned long)v00, (unsigned long)v01, (unsigned long)v02);
    xil_printf("  deep page0: DMA status[31:24], sticky errors[23:21], AXI response error[16], status count[15:0]\r\n");
    xil_printf("  deep page0 words1/2: last DMA command/write addresses\r\n");
#else
    u32 core1 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_CORE1);
    u32 axi0 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_AXI0);
    u32 axi1 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_AXI1);
    u32 c2c = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_C2C);
    u32 p00 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE0_0);
    u32 p01 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE0_0 + 4U);
    u32 p02 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE0_0 + 8U);
    u32 p10 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE1_0);
    u32 p11 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE1_0 + 4U);
    u32 p12 = Xil_In32(LLAMA_CTRL_BASE + LLAMA_DIAG_PIPE1_0 + 8U);

    xil_printf("DIAG %s %lu ms: core0=%08lx core1=%08lx axi0=%08lx axi1=%08lx c2c=%08lx\r\n",
               label, (unsigned long)elapsed_ms,
               (unsigned long)core0, (unsigned long)core1,
               (unsigned long)axi0, (unsigned long)axi1, (unsigned long)c2c);
    xil_printf("  core: bit0 prefill, bits16:1 token, bits24:17 layer; "
               "axi groups[3:0]=ARV [7:4]=ARfire [11:8]=RV [15:12]=RLAST [19:16]=RERR\r\n");
    xil_printf("  pipe0=%08lx/%08lx/%08lx pipe1=%08lx/%08lx/%08lx\r\n",
               (unsigned long)p00, (unsigned long)p01, (unsigned long)p02,
               (unsigned long)p10, (unsigned long)p11, (unsigned long)p12);
#endif
#ifdef ZYNQ7035
    xil_printf("  pipe0 upper16 DMA: err stsV stsLast[7:0] cmdV/R ARV/R RV/R[15:0]\r\n");
    xil_printf("  pipe0 lower16 cmdGen: dense muxSel[15:14] sel[13:11] indexFlowV/indexPushR/indexBlocked/indexPopV/toDenseV[10:6] muxV/R cmdV/R done indexLast[5:0]\r\n");
    xil_printf("  pipe1 upper16 engine: postTag[15:10] cfgV/R wkvV/R axpyV/R preScaleV/R residualV/R\r\n");
    xil_printf("  pipe1 lower16 tagQ: occupancy[15:9] popV[8] tag[7:2] mm2sV/R[1:0]\r\n");
    xil_printf("  pipe2 upper16 cfgGen; low16 dense decoder: sel[15:14] miscCnt[13:11] scaleOcc[10:7] miscV/R zeroV/R scaleV/R mainV\r\n");
#else
    xil_printf("  pipe events: cmdV/cmdF dmaV/dmaF/dmaLast busV/busF/busLast vecV/mlpVec dotV/nextLayer cmdStall/dmaStall/busStall; counts=cmd/dmaLast/busLast/mlpVec; tags=bus/vec/dot\r\n");
    xil_printf("  pipe0 upper16: direct/res/wkvV/wkvF cfgV/cfgF ln vecV/vecF dotV/dotF resAdd/resPop/resOut rope/softmax\r\n");
    xil_printf("  pipe2 low16 distributor: inV/inF denseHit/denseIn main/misc miscPush/tagPush miscPop/tagPop denseV/denseF zero/scale zeroV/scaleV\r\n");
#endif
}

static int check_control_bus(void)
{
    const u32 pattern = 0x51A11A5AU;
    Xil_Out32(LLAMA_CTRL_BASE + LLAMA_SCRATCH_OFFSET, pattern);
    if (Xil_In32(LLAMA_CTRL_BASE + LLAMA_SCRATCH_OFFSET) != pattern) {
        xil_printf("ERROR: AXI-Lite scratch register mismatch\r\n");
        return XST_FAILURE;
    }
    xil_printf("AXI-Lite control test passed\r\n");
    return XST_SUCCESS;
}

static int load_image(const char *path, UINTPTR destination, u32 expected_size)
{
    FRESULT fr;
    u32 offset = 0U;

    fr = f_open(&data_file, path, FA_OPEN_EXISTING | FA_READ);
    if (fr != FR_OK) {
        xil_printf("ERROR: f_open(%s)=%d\r\n", path, (int)fr);
        return XST_FAILURE;
    }
    if (f_size(&data_file) != expected_size) {
        xil_printf("ERROR: %s has wrong size\r\n", path);
        f_close(&data_file);
        return XST_FAILURE;
    }

    while (offset < expected_size) {
        UINT bytes_read = 0U;
        u32 request = expected_size - offset;
        if (request > LOAD_CHUNK_BYTES) request = LOAD_CHUNK_BYTES;
        fr = f_read(&data_file, io_buffer, request, &bytes_read);
        if (fr != FR_OK || bytes_read != request) {
            xil_printf("ERROR: f_read(%s) at %lu: fr=%d read=%u\r\n",
                       path, (unsigned long)offset, (int)fr, bytes_read);
            f_close(&data_file);
            return XST_FAILURE;
        }
        memcpy((void *)(destination + offset), io_buffer, request);
        Xil_DCacheFlushRange(destination + offset, request);
        offset += request;
        if ((offset & 0x01FFFFFFU) == 0U || offset == expected_size) {
            xil_printf("%s: %lu / %lu bytes\r\n", path,
                       (unsigned long)offset, (unsigned long)expected_size);
        }
    }
    f_close(&data_file);
    return XST_SUCCESS;
}

static int compare_tokens(const void *a, const void *b)
{
    return strcmp(((const TokenIndex *)a)->str, ((const TokenIndex *)b)->str);
}

static int load_tokenizer(Tokenizer *t, const char *path)
{
    FRESULT fr;
    UINT got;
    u32 used = 0U;
    int i;

    t->vocab = vocab;
    t->scores = vocab_scores;
    t->sorted = sorted_vocab;
    for (i = 0; i < 256; ++i) {
        t->byte_pieces[i * 2] = (unsigned char)i;
        t->byte_pieces[i * 2 + 1] = 0;
    }

    fr = f_open(&data_file, path, FA_OPEN_EXISTING | FA_READ);
    if (fr != FR_OK) {
        xil_printf("ERROR: f_open(%s)=%d\r\n", path, (int)fr);
        return XST_FAILURE;
    }
    fr = f_read(&data_file, &t->max_token_length, sizeof(t->max_token_length), &got);
    if (fr != FR_OK || got != sizeof(t->max_token_length) || t->max_token_length >= sizeof(token_buffer) / 2U) {
        xil_printf("ERROR: invalid tokenizer header\r\n");
        f_close(&data_file);
        return XST_FAILURE;
    }

    for (i = 0; i < VOCAB_SIZE; ++i) {
        u32 len;
        fr = f_read(&data_file, &t->scores[i], sizeof(float), &got);
        if (fr != FR_OK || got != sizeof(float)) break;
        fr = f_read(&data_file, &len, sizeof(len), &got);
        if (fr != FR_OK || got != sizeof(len) || len > t->max_token_length || used + len + 1U > VOCAB_STORAGE_BYTES) break;
        t->vocab[i] = &vocab_storage[used];
        fr = f_read(&data_file, t->vocab[i], len, &got);
        if (fr != FR_OK || got != len) break;
        t->vocab[i][len] = '\0';
        used += len + 1U;
    }
    f_close(&data_file);
    if (i != VOCAB_SIZE) {
        xil_printf("ERROR: tokenizer parse failed at token %d\r\n", i);
        return XST_FAILURE;
    }
    for (i = 0; i < VOCAB_SIZE; ++i) {
        t->sorted[i].str = t->vocab[i];
        t->sorted[i].id = i;
    }
    qsort(t->sorted, VOCAB_SIZE, sizeof(TokenIndex), compare_tokens);
    xil_printf("Tokenizer loaded: %d tokens, max piece %lu bytes\r\n",
               VOCAB_SIZE, (unsigned long)t->max_token_length);
    return XST_SUCCESS;
}

static int lookup_token(const char *str, Tokenizer *t)
{
    TokenIndex key;
    TokenIndex *found;
    key.str = (char *)str;
    key.id = 0;
    found = (TokenIndex *)bsearch(&key, t->sorted, VOCAB_SIZE,
                                  sizeof(TokenIndex), compare_tokens);
    return found ? found->id : -1;
}

static int encode(Tokenizer *t, const char *text, int *tokens, int capacity)
{
    int count = 0;
    size_t piece_len = 0U;
    const unsigned char *p;

    tokens[count++] = BOS_TOKEN_ID;
    if (*text != '\0') {
        int dummy = lookup_token(" ", t);
        if (dummy < 0 || count >= capacity) return -1;
        tokens[count++] = dummy;
    }

    for (p = (const unsigned char *)text; *p != 0U; ++p) {
        int id;
        size_t i;
        if ((*p & 0xC0U) != 0x80U) piece_len = 0U;
        token_buffer[piece_len++] = (char)*p;
        token_buffer[piece_len] = '\0';
        if ((p[1] & 0xC0U) == 0x80U && piece_len < 4U) continue;
        id = lookup_token(token_buffer, t);
        if (id >= 0) {
            if (count >= capacity) return -1;
            tokens[count++] = id;
        } else {
            for (i = 0; i < piece_len; ++i) {
                if (count >= capacity) return -1;
                tokens[count++] = (unsigned char)token_buffer[i] + 3;
            }
        }
        piece_len = 0U;
    }

    for (;;) {
        float best_score = -1.0e10f;
        int best_id = -1;
        int best_index = -1;
        int i;
        for (i = 0; i < count - 1; ++i) {
            size_t a = strlen(t->vocab[tokens[i]]);
            size_t b = strlen(t->vocab[tokens[i + 1]]);
            int id;
            if (a + b + 1U > sizeof(token_buffer)) return -1;
            memcpy(token_buffer, t->vocab[tokens[i]], a);
            memcpy(token_buffer + a, t->vocab[tokens[i + 1]], b + 1U);
            id = lookup_token(token_buffer, t);
            if (id >= 0 && t->scores[id] > best_score) {
                best_score = t->scores[id];
                best_id = id;
                best_index = i;
            }
        }
        if (best_index < 0) break;
        tokens[best_index] = best_id;
        for (i = best_index + 1; i < count - 1; ++i) tokens[i] = tokens[i + 1];
        --count;
    }
    return count;
}

#ifdef ZYNQ7035
/* The bare-metal BPE encoder does not recognize added special tokens inside
   text. Split the chat template at each literal EOS and insert token 2 so
   user/assistant turns have the same boundary as the model's tokenizer. */
static int encode_chat_prompt(Tokenizer *t, const char *text, int *tokens, int capacity)
{
    int count = 0;
    const char *part = text;
    for (;;) {
        const char *eos = strstr(part, "</s>");
        size_t length = eos ? (size_t)(eos - part) : strlen(part);
        int segment_count;
        int i;
        if (length >= sizeof(chat_segment)) return -1;
        memcpy(chat_segment, part, length);
        chat_segment[length] = '\0';
        segment_count = encode(t, chat_segment, chat_segment_tokens, CHAT_HISTORY_BYTES + 1);
        if (segment_count <= 0) return -1;
        i = 1;
#if CHAT_RAW_DIAGNOSTIC
        if (count == 0) i = 0;
#endif
        /* apply_chat_template(tokenize=True) disables automatic BOS. Keep
           the legacy BOS only for raw diagnostics, not templated chat. */
        for (; i < segment_count; ++i) {
            if (count >= capacity) return -1;
            tokens[count++] = chat_segment_tokens[i];
        }
        if (!eos) return count;
        if (count >= capacity) return -1;
        tokens[count++] = EOS_TOKEN_ID;
        part = eos + 4;
    }
}
#endif

#if defined(ZYNQ7035) && !CHAT_RAW_DIAGNOSTIC
static void clear_chat_history(void)
{
    chat_history[0] = '\0';
    chat_turn_count = 0;
}

static int drop_oldest_chat_turn(void)
{
    size_t used = strlen(chat_history);
    size_t removed;
    int i;
    if (chat_turn_count == 0) return 0;
    removed = chat_turn_bytes[0];
    memmove(chat_history, chat_history + removed, used - removed + 1U);
    for (i = 1; i < chat_turn_count; ++i) chat_turn_bytes[i - 1] = chat_turn_bytes[i];
    --chat_turn_count;
    return 1;
}

static int build_chat_prompt(Tokenizer *t, int include_history)
{
    chat_prompt[0] = '\0';
    if (append_text(chat_prompt, sizeof(chat_prompt), "<|system|>\nYou are a helpful assistant.</s>\n") != XST_SUCCESS ||
        (include_history && append_text(chat_prompt, sizeof(chat_prompt), chat_history) != XST_SUCCESS) ||
        append_text(chat_prompt, sizeof(chat_prompt), "<|user|>\n") != XST_SUCCESS ||
        append_text(chat_prompt, sizeof(chat_prompt), chat_line) != XST_SUCCESS ||
        append_text(chat_prompt, sizeof(chat_prompt), "</s>\n<|assistant|>\n") != XST_SUCCESS) return -1;
    return encode_chat_prompt(t, chat_prompt, prompt_tokens, MAX_PROMPT_TOKENS);
}

static int prepare_chat_prompt(Tokenizer *t, int *dropped)
{
    *dropped = 0;
    /* Reject an oversized new question without destroying existing history. */
    if (build_chat_prompt(t, 0) <= 0) return XST_FAILURE;
    while (build_chat_prompt(t, 1) <= 0) {
        if (!drop_oldest_chat_turn()) return XST_FAILURE;
        ++*dropped;
    }
    return XST_SUCCESS;
}

static int save_chat_turn(void)
{
    const char *parts[] = {"<|user|>\n", chat_line, "</s>\n<|assistant|>\n", chat_reply, "</s>\n"};
    size_t total = 0U;
    unsigned int i;
    for (i = 0U; i < sizeof(parts) / sizeof(parts[0]); ++i) total += strlen(parts[i]);
    if (total >= sizeof(chat_history)) return XST_FAILURE;
    while (chat_turn_count == CHAT_MAX_HISTORY_TURNS ||
           strlen(chat_history) + total >= sizeof(chat_history)) {
        if (!drop_oldest_chat_turn()) return XST_FAILURE;
    }
    /* Reserve the whole turn before appending, so history never contains
       an orphan user/assistant half or depends on delimiters in user text. */
    for (i = 0U; i < sizeof(parts) / sizeof(parts[0]); ++i)
        append_text(chat_history, sizeof(chat_history), parts[i]);
    chat_turn_bytes[chat_turn_count++] = total;
    return XST_SUCCESS;
}
#endif

static const char *decode_piece(Tokenizer *t, int previous, int token)
{
    char *piece;
    if (token < 0 || token >= VOCAB_SIZE) return "";
    piece = t->vocab[token];
    if (previous == BOS_TOKEN_ID && piece[0] == ' ') ++piece;
    if (strlen(piece) == 6U && piece[0] == '<' && piece[1] == '0' && piece[2] == 'x' && piece[5] == '>') {
        int hi = piece[3] <= '9' ? piece[3] - '0' : piece[3] - 'A' + 10;
        int lo = piece[4] <= '9' ? piece[4] - '0' : piece[4] - 'A' + 10;
        if (hi >= 0 && hi < 16 && lo >= 0 && lo < 16)
            return (char *)&t->byte_pieces[(hi * 16 + lo) * 2];
    }
    return piece;
}

static int run_smoke_inference(Tokenizer *t, const char *prompt
#ifdef ZYNQ7035
                               , char *reply, size_t reply_capacity
#endif
                               )
{
#ifdef ZYNQ7035
    int count = encode_chat_prompt(t, prompt, prompt_tokens, MAX_PROMPT_TOKENS);
#else
    int count = encode(t, prompt, prompt_tokens, MAX_PROMPT_TOKENS);
#endif
    int i;
    int previous = BOS_TOKEN_ID;
#ifdef ZYNQ7035
    int output_tokens = 0;
#endif

    if (count <= 0) {
        xil_printf("ERROR: prompt tokenization failed\r\n");
        return XST_FAILURE;
    }
#ifdef ZYNQ7035
    if (count + MAX_DECODE_TOKENS > FPGA_MAX_TOKENS) {
        xil_printf("ERROR: prompt and output exceed FPGA token capacity\r\n");
        return XST_FAILURE;
    }
    if (reply_capacity != 0U) reply[0] = '\0';
#else
    xil_printf("Smoke prompt: %s\r\nPrompt tokens (%d):", prompt, count);
    for (i = 0; i < count; ++i) xil_printf(" %d", prompt_tokens[i]);
    xil_printf("\r\nLLM response:\r\n");
#endif

#ifndef ZYNQ7035
    xil_printf("Control magic=%lu, status=0x%08lx, prefill=0x%08lx, layer=0x%08lx\r\n",
               (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x44U),
               (unsigned long)Xil_In32(LLAMA_CTRL_BASE + LLAMA_RESULT_OFFSET),
               (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x08U),
               (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x20U));
#endif
    /* Keep a cache-independent token trace for JTAG validation when UART is absent. */
    Xil_Out32(TOKEN_TRACE_BASE, TOKEN_TRACE_MAGIC);
    Xil_Out32(TOKEN_TRACE_BASE + 4U, 0U);
    Xil_Out32(LLAMA_CTRL_BASE + LLAMA_RESET_OFFSET, 1U);
    sleep(1U);
    Xil_Out32(LLAMA_CTRL_BASE + LLAMA_TOTAL_OFFSET, (u32)(count + MAX_DECODE_TOKENS));
    for (i = 0; i < count; ++i) {
        u32 command = (i == count - 1 ? 0x00050000U : 0x00030000U) | (u32)prompt_tokens[i];
        Xil_Out32(LLAMA_CTRL_BASE + LLAMA_TOKEN_OFFSET, command);
        usleep(1000U);
#ifdef ZYNQ7035
        /* AXI-Lite token writes have no ready/credit response. Several
           downstream token and prefill-flag FIFOs hold only 64 entries;
           bursting a long history silently drops the tail. The low 16 bits
           of RESULT count completed tokens, so retire this token before
           submitting the next one. This also keeps the last-prefill marker
           aligned with the token data in every consumer. */
        {
            u32 prefill_wait;
            for (prefill_wait = 0U; prefill_wait < RESULT_TIMEOUT_MS; ++prefill_wait) {
                u32 completed = Xil_In32(LLAMA_CTRL_BASE + LLAMA_RESULT_OFFSET) & 0xFFFFU;
                if (completed >= (u32)(i + 1)) break;
                usleep(1000U);
            }
            if (prefill_wait == RESULT_TIMEOUT_MS) {
                print_diagnostics("prefill-timeout", prefill_wait);
                xil_printf("\r\nERROR: prefill token %d did not retire\r\n", i);
                return XST_FAILURE;
            }
        }
#endif
    }
#ifndef ZYNQ7035
    xil_printf("After prompt: status=0x%08lx, prefill=0x%08lx, layer=0x%08lx\r\n",
               (unsigned long)Xil_In32(LLAMA_CTRL_BASE + LLAMA_RESULT_OFFSET),
               (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x08U),
               (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x20U));
    print_diagnostics("after-prompt", 0U);
#endif

    for (i = 0; i < MAX_DECODE_TOKENS; ++i) {
        u32 result = 0U;
        u32 waited;
        int token;
        for (waited = 0U; waited < RESULT_TIMEOUT_MS; ++waited) {
            result = Xil_In32(LLAMA_CTRL_BASE + LLAMA_RESULT_OFFSET);
            if ((result & 0x80000000U) != 0U) break;
#ifndef ZYNQ7035
            if ((waited == 10U || waited == 100U || waited == 1000U ||
                           waited == 10000U || waited == 60000U))
                print_diagnostics("waiting", waited);
#endif
            usleep(1000U);
        }
        if ((result & 0x80000000U) == 0U) {
            print_diagnostics("timeout", waited);
            xil_printf("\r\nERROR: inference timeout at output token %d, status=0x%08lx\r\n",
                       i, (unsigned long)result);
            return XST_FAILURE;
        }
        token = (int)((result >> 16) & 0x7FFFU);
        Xil_Out32(TOKEN_TRACE_BASE + 8U + (u32)i * 4U, (u32)token);
        Xil_Out32(TOKEN_TRACE_BASE + 4U, (u32)(i + 1));
#ifdef ZYNQ7035
        if (token != EOS_TOKEN_ID) {
            const char *piece = decode_piece(t, previous, token);
            xil_printf("%s", piece);
            if (append_text(reply, reply_capacity, piece) != XST_SUCCESS) {
                Xil_Out32(LLAMA_CTRL_BASE + LLAMA_RESULT_ACK, 1U);
                xil_printf("\r\n[reply buffer full]\r\n");
                return XST_FAILURE;
            }
            ++output_tokens;
        }
#else
        xil_printf("[%d]", token);
        xil_printf("%s", decode_piece(t, previous, token));
#endif
#ifdef ZYNQ7035
        /* Do not launch a throwaway decode after the final answer token.
           The next prompt may soft-reset immediately, while that decode's
           AXI/DMA traffic is still in flight. */
        if (token != EOS_TOKEN_ID && i + 1 < MAX_DECODE_TOKENS)
            Xil_Out32(LLAMA_CTRL_BASE + LLAMA_TOKEN_OFFSET, 0x00090000U | (u32)token);
#else
        Xil_Out32(LLAMA_CTRL_BASE + LLAMA_TOKEN_OFFSET, 0x00090000U | (u32)token);
#endif
        Xil_Out32(LLAMA_CTRL_BASE + LLAMA_RESULT_ACK, 1U);
        previous = token;
        if (token == EOS_TOKEN_ID) break;
    }
#ifdef ZYNQ7035
    if (previous == EOS_TOKEN_ID)
        xil_printf("\r\n[answer complete: eos, %d output tokens]\r\n", output_tokens);
    else
        xil_printf("\r\n[answer truncated: output limit %d tokens reached]\r\n", MAX_DECODE_TOKENS);
#else
    xil_printf("\r\nSmoke inference finished\r\n");
#endif
    return XST_SUCCESS;
}

#ifdef ZYNQ7035
static void print_probe_pages(void)
{
    u32 page;
    for (page = 0U; page < 4U; ++page) {
        Xil_Out32(LLAMA_CTRL_BASE + 0xC4U, page);
        usleep(1000U);
        if (Xil_In32(LLAMA_CTRL_BASE + 0xC4U) != page) {
            xil_printf("[probe page selector unavailable]\r\n");
            break;
        }
        xil_printf("PROBE_PAGE_%lu %08lx %08lx %08lx\r\n", (unsigned long)page,
                   (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x54U),
                   (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x58U),
                   (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x5CU));
    }
    Xil_Out32(LLAMA_CTRL_BASE + 0xC4U, 0U);
}

static void print_vector_snapshot(void)
{
    u32 index, residual_count, ug_count, post_mlp_count;
    Xil_Out32(LLAMA_CTRL_BASE + 0xC4U, 3U);
    Xil_Out32(LLAMA_CTRL_BASE + 0xC8U, 4096U);
    usleep(1000U);
    residual_count = Xil_In32(LLAMA_CTRL_BASE + 0x54U);
    ug_count = Xil_In32(LLAMA_CTRL_BASE + 0x58U);
    post_mlp_count = Xil_In32(LLAMA_CTRL_BASE + 0x5CU);
    xil_printf("MLP_COUNTS %lu %lu %lu\r\n", (unsigned long)residual_count,
               (unsigned long)ug_count, (unsigned long)post_mlp_count);
    if (residual_count == 2048U && ug_count == 5632U && post_mlp_count == 2048U) {
        for (index = 0U; index < 2816U; ++index) {
            Xil_Out32(LLAMA_CTRL_BASE + 0xC8U, index);
            usleep(50U);
            xil_printf("MLP_PAIR %lu %08lx %08lx %08lx\r\n", (unsigned long)index,
                       (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x54U),
                       (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x58U),
                       (unsigned long)Xil_In32(LLAMA_CTRL_BASE + 0x5CU));
        }
    }
    Xil_Out32(LLAMA_CTRL_BASE + 0xC8U, 0U);
    Xil_Out32(LLAMA_CTRL_BASE + 0xC4U, 0U);
}

static int run_chat_console(Tokenizer *t)
{
#if CHAT_RAW_DIAGNOSTIC
    chat_history[0] = '\0';
#else
    clear_chat_history();
#endif
    xil_printf("Interactive TinyLlama ready. UTF-8 input; /reset clears history; /exit quits.\r\n");
    xil_printf("Input/history budget: %d tokens; output limit: %d tokens; oldest full turns are trimmed when needed.\r\n",
               MAX_PROMPT_TOKENS, MAX_DECODE_TOKENS);
    for (;;) {
        int status;
        xil_printf("\r\nYou> ");
        read_chat_line(chat_line, sizeof(chat_line));
        if (strcmp(chat_line, "/exit") == 0) return XST_SUCCESS;
        if (strcmp(chat_line, "/probe") == 0) {
            print_probe_pages();
            continue;
        }
        if (strcmp(chat_line, "/vectors") == 0 || strcmp(chat_line, "/mlpvectors") == 0) {
            print_vector_snapshot();
            continue;
        }
        if (strcmp(chat_line, "/reset") == 0) {
#if CHAT_RAW_DIAGNOSTIC
            chat_history[0] = '\0';
#else
            clear_chat_history();
#endif
            xil_printf("[history cleared]\r\n");
            continue;
        }
        if (chat_line[0] == '\0') continue;
        chat_prompt[0] = '\0';
#if CHAT_RAW_DIAGNOSTIC
        status = append_text(chat_prompt, sizeof(chat_prompt), chat_line);
        if (status != XST_SUCCESS || encode_chat_prompt(t, chat_prompt, prompt_tokens, MAX_PROMPT_TOKENS) <= 0) {
            xil_printf("[input too long; use fewer characters]\r\n");
            continue;
        }
#else
        {
            int dropped;
            status = prepare_chat_prompt(t, &dropped);
            if (status != XST_SUCCESS) {
                xil_printf("[input too long; use fewer characters]\r\n");
                continue;
            }
            if (dropped != 0)
                xil_printf("[trimmed %d oldest full turns to fit %d-token input]\r\n", dropped, MAX_PROMPT_TOKENS);
        }
#endif
        xil_printf("Assistant> ");
        if (run_smoke_inference(t, chat_prompt, chat_reply, sizeof(chat_reply)) != XST_SUCCESS) {
            xil_printf("[inference failed; reload or reset the board]\r\n");
            return XST_FAILURE;
        }
#if !CHAT_RAW_DIAGNOSTIC
        if (save_chat_turn() != XST_SUCCESS)
            xil_printf("[turn too large for history; previous history retained]\r\n");
#endif
    }
}
#endif

int main(void)
{
    FRESULT fr;
    Tokenizer tokenizer;
    u32 mount_retry;

#ifdef ZYNQ7035
    xil_printf("Zynq-7035 EdgeLLM 1.1B single-core inference loader\r\n");
    xil_printf("Build: round55 chat128 repetition penalty 1.125 20261101; Round54 KV + Round52 arithmetic\r\n");
#else
    xil_printf("Zynq-7100 EdgeLLM 1.1B inference loader\r\n");
#endif
    if (check_control_bus() != XST_SUCCESS) return XST_FAILURE;
    fr = FR_NOT_READY;
    for (mount_retry = 0U; mount_retry < 20U; ++mount_retry) {
        fr = f_mount(&fatfs, "0:/", 1);
        if (fr == FR_OK) break;
        xil_printf("SD not ready (%d), retry %lu/20\r\n",
                   (int)fr, (unsigned long)(mount_retry + 1U));
        usleep(500000U);
    }
    if (fr != FR_OK) {
        xil_printf("ERROR: SD mount failed: %d\r\n", (int)fr);
        return XST_FAILURE;
    }
#ifdef ZYNQ7035
    if (load_image("0:/llm.bin", PS_MODEL_BASE, MODEL_IMAGE_BYTES) != XST_SUCCESS ||
        load_tokenizer(&tokenizer, "0:/tkz.bin") != XST_SUCCESS) {
#else
    if (load_image("0:/llmps.bin", PS_MODEL_BASE, MODEL_IMAGE_BYTES) != XST_SUCCESS ||
        load_image("0:/llmpl.bin", PL_MODEL_BASE, MODEL_IMAGE_BYTES) != XST_SUCCESS ||
        load_tokenizer(&tokenizer, "0:/tkz.bin") != XST_SUCCESS) {
#endif
        f_mount(NULL, "0:/", 0);
        return XST_FAILURE;
    }
    f_mount(NULL, "0:/", 0);
#ifdef ZYNQ7035
    xil_printf("FPGA model image loaded successfully\r\n");
#else
    xil_printf("Both FPGA model images loaded successfully\r\n");
#endif
#ifdef ZYNQ7035
    return run_chat_console(&tokenizer);
#else
    return run_smoke_inference(&tokenizer, "Hello");
#endif
}
