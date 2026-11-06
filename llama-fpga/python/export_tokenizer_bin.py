import argparse
import struct
from pathlib import Path

import sentencepiece as spm


def main() -> None:
    parser = argparse.ArgumentParser(description="Export a Llama SentencePiece tokenizer for the FPGA SDK")
    parser.add_argument("--model-path", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    sp = spm.SentencePieceProcessor(model_file=str(args.model_path / "tokenizer.model"))
    vocab_size = sp.get_piece_size()
    if vocab_size != 32000:
        raise ValueError(f"expected a 32000-piece vocabulary, got {vocab_size}")
    if (sp.bos_id(), sp.eos_id(), sp.unk_id()) != (1, 2, 0):
        raise ValueError("expected TinyLlama special token ids unk/bos/eos = 0/1/2")

    pieces = [sp.id_to_piece(i).replace("\u2581", " ").encode("utf-8") for i in range(vocab_size)]
    max_token_length = max(len(piece) for piece in pieces)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as output:
        output.write(struct.pack("<I", max_token_length))
        for token_id, piece in enumerate(pieces):
            output.write(struct.pack("<fI", float(sp.get_score(token_id)), len(piece)))
            output.write(piece)

    print(f"wrote {args.output} ({args.output.stat().st_size} bytes)")
    print(f"vocab_size={vocab_size} max_token_length={max_token_length}")
    print(f"bos={sp.bos_id()} eos={sp.eos_id()} unk={sp.unk_id()}")


if __name__ == "__main__":
    main()
