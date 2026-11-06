"""Analyze Round55 UART control and repetition evidence; keep semantics explicit."""
import argparse
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('round54_probe_decoder', ROOT / 'zynq7035_port/software/round54/analyze_board.py')
decoder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(decoder)
STOP = re.compile(r'^\[answer (?:complete: eos, (\d+) output tokens|truncated: output limit (\d+) tokens reached)\]$', re.M)

def repeated_span(text):
    words = re.findall(r'\w+|[^\w\s]', text.casefold())
    for length in range(12, min(49, len(words)//2+1)):
        for start in range(len(words)-2*length+1):
            if words[start:start+length] == words[start+length:start+2*length]:
                return dict(start=start, length=length, text=' '.join(words[start:start+length]))
    return None

def analyze(path):
    text = path.read_text(encoding='utf-8-sig').replace('\r\n', '\n')
    expected = json.loads(Path(str(path)+'.inputs.json').read_text(encoding='utf-8-sig'))
    commands, answers, probes = [], [], []
    for section in re.split(r'^You> ', text, flags=re.M)[1:]:
        command, _, body = section.partition('\n')
        if not command:
            continue
        commands.append(command)
        if command == '/probe':
            probes.append(decoder.probe(body))
        if command.startswith('/'):
            continue
        stops = list(STOP.finditer(body))
        end = stops[-1] if stops else None
        answer = body.partition('Assistant> ')[2]
        if end:
            answer = answer.split(end.group(0))[0].strip()
        answers.append(dict(prompt=command, answer=answer, end_markers=len(stops),
            stop_reason=('eos' if end.group(1) else 'length') if end else None,
            output_tokens=int(end.group(1) or end.group(2)) if end else None,
            legacy_loop_phrase_occurrences=answer.lower().count("i'm glad to hear that you found my previous message helpful."),
            consecutive_repeated_span_heuristic=repeated_span(answer)))
    errors = re.findall(r'^.*(?:ERROR:|\[inference failed|\[reply buffer full).*$', text, re.M)
    complete = (commands == expected and len(answers) == 10 and all(a['end_markers'] == 1 for a in answers)
                and len(probes) == 2 and all(p['healthy'] for p in probes) and not errors
                and 'Build: round55 chat128 repetition penalty 1.125 20261101' in text
                and '937803776 / 937803776 bytes' in text)
    return dict(control_and_dma_checks_passed=complete, completed_answers=sum(a['end_markers'] == 1 for a in answers),
        expected_answers=10, all_expected_commands_seen=commands == expected, error_lines=errors,
        eos_answers=sum(a['stop_reason'] == 'eos' for a in answers),
        length_limited_answers=sum(a['stop_reason'] == 'length' for a in answers),
        history_trim_messages=re.findall(r'^\[trimmed .*$', text, re.M), answers=answers, probes=probes,
        scope='One cold boot, fixed10-prompt suite; repetition detector is a text heuristic; semantic review remains separate')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--partial', action='store_true')
    args = parser.parse_args()
    report = analyze(args.log)
    output = Path(str(args.log)+('.progress.json' if args.partial else '.analysis.json'))
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ('answers','probes')}, ensure_ascii=False))
    for row in report['answers']:
        print(row['prompt'], row['stop_reason'], row['output_tokens'], row['answer'][:100])
    if not args.partial and not report['control_and_dma_checks_passed']:
        raise SystemExit(1)
