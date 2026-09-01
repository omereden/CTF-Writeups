Drop JetBrains Mono and Inter .ttf files here to embed them regardless of the
build machine's installed fonts. The template's font stack falls back to system
fonts (Menlo / Helvetica) and finally DejaVu, so this is optional. To force them,
compile with:  typst compile --font-path template/assets ...
