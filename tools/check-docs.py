"""Check local Markdown targets and fictional media without accessing credentials."""
from pathlib import Path
import re
from PIL import Image

root = Path(__file__).resolve().parents[1]
files = list(root.glob('*.md')) + list((root / 'docs').rglob('*.md'))
errors = []
for file in files:
    for target in re.findall(r'\]\(([^)]+)\)', file.read_text(encoding='utf-8-sig')):
        target = target.split('#', 1)[0]
        if target and not target.startswith(('https://', 'http://', 'mailto:')):
            if not (file.parent / target).exists():
                errors.append(f'{file.relative_to(root)}: missing {target}')
with Image.open(root / 'docs/media/social-preview.png') as banner:
    assert banner.size == (1280, 640)
assert (root / 'docs/media/social-preview.png').stat().st_size < 1000000
with Image.open(root / 'docs/media/quickstart.gif') as gif:
    assert gif.n_frames == 4
    for index in range(gif.n_frames):
        gif.seek(index)
        assert gif.info['duration'] == 5000
if errors:
    raise SystemExit('\n'.join(errors))
print(f'PASS local Markdown targets ({len(files)} documents), preview dimensions, and 20-second GIF.')
