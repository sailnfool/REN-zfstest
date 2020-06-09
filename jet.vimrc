" VIM Configuration File
" Description: Optimized for C/C++ development, but useful also for other things.
" Author: Gerhard Gappmeier
"
" configure tabwidth and insert spaces instead of tabs
"set tabstop=4        " tab width is 4 spaces
"set shiftwidth=4     " indent also with 4 spaces
"set softtabstop=4    " see :h 'softtabstop'
" wrap lines at 120 chars. 80 is somewaht antiquated with nowadays displays.
" Install OmniCppComplete like described on http://vim.wikia.com/wiki/C++_code_completion
" This offers intelligent C++ completion when typing ‘.’ ‘->’ or <C-o>
" Load standard tag files
" set tags+=~/.vim/tags/cpp
" set tags+=~/.vim/tags/gl
" set tags+=~/.vim/tags/sdl
" set tags+=~/.vim/tags/qt4
" Enhanced keyboard mappings
"
" nmap <F2> :w<CR> " in normal mode F2 will save the file
" imap <F2> <ESC>:w<CR>i " in insert mode F2 will exit insert, save, enters insert again
" map <F4> :e %:p:s,.h$,.X123X,:s,.cpp$,.h,:s,.X123X$,.cpp,<CR> " switch between header/source with F4
" map <F5> :!ctags -R –c++-kinds=+p –fields=+iaS –extra=+q .<CR> " recreate tags file with F5
" map <F6> :Dox<CR> " create doxygen comment
" map <F7> :make<CR> " build using makeprg with <F7>
" map <S-F7> :make clean all<CR> " build using makeprg with <S-F7>
" map <F12> <C-]> " goto definition with F12
" " in diff mode we use the spell check keys for merging
" if &diff
"   ” diff settings
"   map <M-Down> ]c
"   map <M-Up> [c
"   map <M-Left> do
"   map <M-Right> dp
"   map <F9> :new<CR>:read !svn diff<CR>:set syntax=diff buftype=nofile<CR>gg
" else
"   " spell settings
"   :setlocal spell spelllang=en
"   " set the spellfile - folders must exist
"   set spellfile=~/.vim/spellfile.add
"   map <M-Down> ]s
"   map <M-Up> [s
" endif

set enc=utf-8 " set UTF-8 encoding
set fenc=utf-8
set termencoding=utf-8
set nocompatible " disable vi compatibility (emulation of old bugs)
set autoindent " use indentation of previous line
set noexpandtab
set smartindent " use intelligent indentation for C
filetype indent on
set wildmenu
set incsearch
set title
set nowrap
set backspace=indent,eol,start
set textwidth=120
set t_Co=256 " turn syntax highlighting on
syntax on
" colorscheme desert 
set number " turn line numbers on
set showmatch " highlight matching braces
set comments=sl:/*,mb:\ *,elx:\ */ " intelligent comments
set tags=./tags,tags;$HOME,.git/tags
let g:DoxygenToolkit_authorName="Robert E. Novak<sailnfool@gmail.com>" " Install DoxygenToolkit from http://www.vim.org/scripts/script.php?script_id=987
set lines=80
set columns=85
set colorcolumn=72
set winheight=999
set winminheight=0
