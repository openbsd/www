all: html txt info # ps

html:
	perl texi2html -iso -number openbsdfaq.texi

ps:
	MAKEINFO='makeinfo -I .' texi2dvi openbsdfaq.texi

txt:
	makeinfo -I . --no-headers --no-split --output openbsdfaq.txt openbsdfaq.texi

info:
	makeinfo -I . openbsdfaq.texi
