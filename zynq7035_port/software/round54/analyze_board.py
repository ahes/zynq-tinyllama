"""Analyze a Round54 UART capture; report control, DMA and content separately."""
import argparse
import json
from pathlib import Path
import re

BANNER = 'Build: round54 chat128 KV metadata repair 20261101'
STOP = re.compile(r'^\[answer (?:complete: eos, (\d+) output tokens|truncated: output limit (\d+) tokens reached)\]$', re.M)


def probe(section):
    pages = {int(n): [int(x, 16) for x in (a, b, c)] for n, a, b, c in
             re.findall(r'^PROBE_PAGE_(\d) ([0-9A-Fa-f]{8}) ([0-9A-Fa-f]{8}) ([0-9A-Fa-f]{8})$', section, re.M)}
    if set(pages) != {0, 1, 2, 3}:
        return {'complete': False, 'healthy': False}
    word = pages[0][0]
    last_status = word >> 24
    counts = dict(status=word & 0xFFFF, command=pages[2][0] >> 16,
                  packet=pages[2][0] & 0xFFFF, response=pages[2][1] & 0xFFFF)
    errors = dict(sticky_interr=bool(word & (1 << 21)), sticky_decerr=bool(word & (1 << 22)),
                  sticky_slverr=bool(word & (1 << 23)), axi_response_error=bool(word & (1 << 16)))
    idle = all(n == 0 for n in counts.values()) and last_status == 0
    healthy = (not any(errors.values()) and len(set(counts.values())) == 1 and
               (idle or (last_status & 0xF0) == 0x80) and
               pages[2][1] >> 16 == counts['status'] and
               ((pages[2][2] >> 1) & 0xFF) == last_status and
               not (pages[2][2] & 1))
    return dict(complete=True, healthy=healthy, idle_before_inference=idle,
                last_status=f'{last_status:02X}', errors=errors, counts_mod65536=counts,
                last_command_address=f'{pages[0][1]:08X}', last_write_address=f'{pages[0][2]:08X}',
                raw_pages={str(k): [f'{x:08X}' for x in v] for k, v in pages.items()})


def analyze(path):
    text = path.read_text(encoding='utf-8-sig').replace('\r\n', '\n')
    expected = json.loads(Path(str(path) + '.inputs.json').read_text(encoding='utf-8-sig'))
    sections = re.split(r'^You> ', text, flags=re.M)[1:]
    commands, answers, probes = [], [], []
    for section in sections:
        command, _, body = section.partition('\n')
        commands.append(command)
        if command == '/probe':
            probes.append(probe(body))
        if command.startswith('/'):
            continue
        stops = list(STOP.finditer(body))
        answer = body.partition('Assistant> ')[2]
        if stops:
            answer = body.partition('Assistant> ')[2].split(stops[-1].group(0))[0].strip()
        end = stops[-1] if stops else None
        answers.append(dict(prompt=command, answer=answer, end_markers=len(stops),
                            stop_reason=('eos' if end.group(1) is not None else 'length') if end else None,
                            output_tokens=int(end.group(1) or end.group(2)) if end else None))
    all_commands_seen = commands == expected + ['/exit']
    error_lines = re.findall(r'^.*(?:ERROR:|\[inference failed|\[reply buffer full).*$', text, re.M)
    control_ok = (BANNER in text and '937803776 / 937803776 bytes' in text and
                  'output limit: 128 tokens' in text and all_commands_seen and
                  len(answers) == 8 and all(a['end_markers'] == 1 for a in answers) and
                  not error_lines and len(probes) == 2 and all(p['healthy'] for p in probes))
    semantic = {}
    if len(answers) == 8:
        code = answers[1]['answer']
        semantic = dict(c_program_has_stdio=bool(re.search(r'#include\s*<stdio\.h>', code)),
                        c_program_has_main_and_printf='main' in code and 'printf' in code,
                        c_program_has_return_zero=bool(re.search(r'return\s+0\s*;', code)),
                        c_program_ended_at_eos=answers[1]['stop_reason'] == 'eos',
                        chinese_math_contains_four=bool(re.search(r'4|四', answers[2]['answer'])),
                        apple_recalled='apple' in answers[4]['answer'].lower(),
                        latest_mango_recalled='mango' in answers[7]['answer'].lower())
    return dict(log=str(path), control_and_dma_checks_passed=control_ok,
                expected_commands_and_exit_seen=all_commands_seen, error_lines=error_lines,
                completed_answers=sum(a['end_markers'] == 1 for a in answers),
                length_limited_answers=sum(a['stop_reason'] == 'length' for a in answers),
                eos_answers=sum(a['stop_reason'] == 'eos' for a in answers),
                history_trim_messages=re.findall(r'^\[trimmed .*$', text, re.M),
                basic_content_checks=semantic, answers=answers, probes=probes,
                validation_scope='Eight prompts on one Round54 cold boot; content checks are heuristics, not proof of general dialogue reliability')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = analyze(args.log)
    output = args.output or Path(str(args.log) + '.analysis.json')
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k not in ('answers', 'probes')}, ensure_ascii=False, indent=2))
    print(f'REPORT={output}')
    raise SystemExit(0 if report['control_and_dma_checks_passed'] else 1)


if __name__ == '__main__':
    main()
