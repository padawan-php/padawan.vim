let s:save_cpo = &cpo
set cpo&vim

"setlocal omnifunc=padawan#Complete

let &cpo = s:save_cpo
unlet s:save_cpo
