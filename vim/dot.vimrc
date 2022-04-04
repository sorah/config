" sorah's vimrc
" License: Public Domain

set nocompatible

"Absorb vimrc/.vim in Windows {{{
if has('win32') || has ('win64')
  set shellslash
  let $VIMFILES = $USERPROFILE.'\git\config\vim\dot.vim'
else
  let $VIMFILES = $HOME."/.vim"
endif

if has('vim_starting') && (has('win32') || has('win64'))
  set runtimepath+=~/git/config/vim/dot.vim
endif
"}}}


" Bundle {{{
filetype off
set runtimepath+=~/.vim-dein/cache/repos/github.com/Shougo/dein.vim
if dein#load_state('~/.vim-dein/state')
  call dein#begin('~/.vim-dein/state')
  "NeoBundle 'mrkn/mrkn256.vim'
  call dein#add('mattn/webapi-vim')
  call dein#add('tpope/vim-rails')
  call dein#add('plasticboy/vim-markdown')
  call dein#add('motemen/git-vim')
  call dein#add('thinca/vim-quickrun')
  "all dein#add('Shougo/neocomplcache')
  call dein#add('ujihisa/unite-gem')
  call dein#add('Shougo/unite-outline')
  call dein#add('Shougo/unite.vim')
  call dein#add('kchmck/vim-coffee-script')
  call dein#add('kana/vim-metarw')
  call dein#add('kana/vim-metarw-git')
  call dein#add('thinca/vim-ref')
  call dein#add('taka84u9/vim-ref-ri')
  call dein#add('Shougo/vimproc', { 'build': 'make' })
  call dein#add('godlygeek/csapprox')
  call dein#add('ujihisa/shadow.vim')
  call dein#add('cakebaker/scss-syntax.vim')
  call dein#add('tpope/vim-haml')
  "call dein#add('Shougo/neosnippet')
  call dein#add('taka84u9/unite-git')
  call dein#add('thinca/vim-scouter')
  call dein#add('altercation/vim-colors-solarized')
  call dein#add('tyru/eskk.vim')
  call dein#add('tyru/skkdict.vim')
  call dein#add('kana/vim-textobj-user')
  call dein#add('kana/vim-smartword')
  call dein#add('nelstrom/vim-textobj-rubyblock')
  call dein#add('nathanaelkane/vim-indent-guides')
  call dein#add('kana/vim-smartchr')
  call dein#add('kana/vim-smartinput')
  call dein#add('sgur/unite-git_grep')
  call dein#add('sorah/puppet.vim')
  call dein#add('noprompt/vim-yardoc')
  call dein#add('nanotech/jellybeans.vim')
  call dein#add('Lokaltog/vim-distinguished')
  call dein#add('tomasr/molokai')
  call dein#add('jonathanfilip/vim-lucius')
  call dein#add('w0ng/vim-hybrid')
  call dein#add('nginx/nginx', {'rtp': 'contrib/vim/'})
  call dein#add('sorah/unite-ghq')
  call dein#add('sorah/unite-bundler')
  call dein#add('eagletmt/vim-ruby_namespace')
  call dein#add('sorah/unite-outline-piculet')
  call dein#add('pangloss/vim-javascript')
  call dein#add('mxw/vim-jsx')
  call dein#add('vim-scripts/rfc-syntax')
  call dein#add('smerrill/vcl-vim-plugin')
  call dein#add('posva/vim-vue')
  call dein#add('nfnty/vim-nftables')
  call dein#add('zimbatm/haproxy.vim')
  call dein#add('dense-analysis/ale')
  call dein#add('rust-lang/rust.vim')
  call dein#add('racer-rust/vim-racer')
  call dein#add('google/vim-jsonnet')
  call dein#add('hashivim/vim-hashicorp-tools')
  call dein#add('hashivim/vim-terraform')
  call dein#add('HerringtonDarkholme/yats.vim')
  call dein#add('kevinoid/vim-jsonc')
  call dein#add('PProvost/vim-ps1')

  if has('nvim')
    "call dein#add('mhartington/nvim-typescript', { 'build' : './install.sh' })
    call dein#add('neoclide/coc.nvim', { 'rev': 'release' })
  endif

  call dein#end()
  call dein#save_state()
endif

let g:coc_global_extensions = [
  \   "coc-clangd",
  \   "coc-css",
  \   "coc-dictionary",
  \   "coc-emoji",
  \   "coc-go",
  \   "coc-html",
  \   "coc-json",
  \   "coc-omni",
  \   "coc-rust-analyzer",
  \   "coc-solargraph",
  \   "coc-syntax",
  \   "coc-tag",
  \   "coc-tsserver",
  \   "coc-word",
  \ ]

filetype on
filetype plugin on
filetype indent on
runtime macros/matchit.vim
" }}}


" Basic {{{

" ruby - developer {{{
au FileType c setlocal ts=8 sw=4 noexpandtab
au FileType ruby setlocal nowrap tabstop=8 tw=0 sw=2 expandtab
let g:changelog_timeformat="%a %b %e %T %Y"
let g:changelog_username = "Sorah Fukumori  <her@sorah.jp>"
" }}}

"delete all autocmds
autocmd!

" view setting {{{
set number

"- -> >>- --->
set list
set listchars=tab:>-,trail:-,extends:>,precedes:<
" }}}

" encoding settings {{{
set enc=utf-8
set fencs=utf-8,iso-2022-jp,euc-jp,cp932,ucs-bom,default,latin1
set ambiwidth=double
set fileformats=unix,dos,mac
lang en_US.UTF-8
"}}}

" path setting {{{
if !exists("g:sorah_vimrc_loaded")
  if !has('win32') && !has('win64') && has('gui_running')
    let $PATH=$HOME."/.rbenv/shims:".$HOME."/.rbenv/bin:".$HOME."/local/bin:".$PATH
    let $GOPATH=$HOME."/.gopath"
    let $PATH="/usr/local/opt/go/libexec:".$PATH
    let $PATH=$HOME."/.gopath/bin:".$PATH
  endif
endif
"}}}

"search settings {{{
set ignorecase
set smartcase
set wrapscan
set incsearch
set hlsearch
"}}}

"indent settings {{{
set autoindent
set cindent
set tabstop=2
set shiftwidth=2
set smarttab
set expandtab
"}}}

" make hidden instead of unloading
set hidden

"command-line settings {{{
set showcmd
set cmdheight=2
set laststatus=2
set statusline=%f\ %m%r%h%w%{(&fenc!='utf-8'?'['.&fenc.']':'')}%#warningmsg%*%=%<%{substitute(fnamemodify(getcwd(),\ ':~'),\ '^\\~/Dropbox/\\(git\\\\|sandbox\\)',\ '-\\1',\ '')}\ [%l,%c]\ %p%%
"}}}

"split
set splitbelow
set splitright

" command completion
set wildmenu
set wildmode=list:longest

" for Japanese
set noimdisable
set noimcmdline
set iminsert=1
set imsearch=1

" other
set noruler
set showmatch
set wrap
set title
set backspace=indent,eol,start
set scrolloff=5
set formatoptions& formatoptions+=mM
set tw=0
set nobackup
set nowritebackup
set history=1000
set mouse=a
set noautochdir

" coc.nvim requirement
set updatetime=300
set shortmess+=c
if has("patch-8.1.1564")
  set signcolumn=number
else
  set signcolumn=yes
endif

"enable filetype plugins
filetype plugin on
filetype plugin indent on
syntax enable

" search mappings {{{
noremap n nzzzv
noremap N Nzzzv
noremap * *zzzv
noremap # #zzzv
noremap g* g*zzzv
noremap g# g#zzzv
" }}}

set pumheight=10
set clipboard=unnamed
if has('nvim')
  " Save only the last register
  set shada=!,'100,<1,s10,h
endif


" folding {{{
set foldenable
set foldmethod=marker
set foldcolumn=1
"}}}

"color settings {{{
if !has('gui_running')
  set t_AB=[48;5;%dm
  set t_AF=[38;5;%dm
  set t_Co=256
endif

let g:hybrid_custom_term_colors = 0
let g:hybrid_reduced_contrast = 0
set background=dark
colorscheme hybrid
hi Normal ctermbg=none

"}}}

"mouse setting {{{
if !has('gui_running') && !has('nvim')
  set mouse=a
  if exists('$WINDOW') || exists('$TMUX')
    set ttymouse=xterm2
  endif
endif
"}}}

"gui {{{
if has('gui_running')
  if has('mac')
    " set guifont=Inconsolata:h14
    if !exists("g:sorah_vimrc_loaded")
      set guifont=Source\ Code\ Pro:h14
      set guifontwide=MigMix\ 1P:h14
      set columns=170
      set lines=44
    endif
    set transparency=15
    nnoremap <silent> F :<C-u>set fullscreen!<Cr>
  endif

  set guioptions=gmt
endif
"}}}

" swap is in ~/tmp {{{
set directory-=.
"}}}

set autoread

" }}}


" autocmd {{{
" ruby autocmds {{{
augroup SorahRuby
  autocmd!
  autocmd Filetype ruby inoremap <buffer> <expr> { smartchr#loop('{','#{','{{')
augroup END
"}}}

" unite.vim {{{
augroup MyUniteVim
  autocmd!
  autocmd FileType unite nmap <buffer> u <Plug>(unite_redraw)
augroup END
"}}}

"vimrc auto update {{{
augroup MyAutoCmd
  autocmd!
  autocmd BufWritePost .vimrc nested source $MYVIMRC
  " autocmd BufWritePost .vimrc RcbVimrc
augroup END
"}}}

"crontab for Vim {{{
augroup CrontabForVim
  autocmd BufReadPre crontab.* setl nowritebackup
augroup END
"}}}

"http://codenize.tools/

augroup CodenizeToolsFt
  autocmd!

  autocmd BufWinEnter,BufNewFile ELBFile setf ruby
  autocmd BufWinEnter,BufNewFile ELBfile setf ruby
  autocmd BufWinEnter,BufNewFile *.elb setf ruby

  autocmd BufWinEnter,BufNewFile IAMFile setf ruby
  autocmd BufWinEnter,BufNewFile IAMfile setf ruby
  autocmd BufWinEnter,BufNewFile *.iam setf ruby

  autocmd BufWinEnter,BufNewFile Groupfile setf ruby
  autocmd BufWinEnter,BufNewFile *.group setf ruby

  autocmd BufWinEnter,BufNewFile EIPfile setf ruby
  autocmd BufWinEnter,BufNewFile EIPFile setf ruby
augroup END

" vagrant
augroup VagrantFt
  autocmd!

  autocmd BufWinEnter,BufNewFile Vagrantfile setf ruby
augroup END

augroup EssixFt
  autocmd!

  autocmd BufWinEnter,BufNewFile *.es6 setf javascript
augroup END

augroup TerraformFt
  autocmd!

  autocmd BufWinEnter,BufNewFile *.tf setf terraform
augroup END
"}}}

"coc.nvim
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window.
function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction
nnoremap <silent> K :call <SID>show_documentation()<CR>

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code.
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

" Applying codeAction to the selected region.
" Example: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap keys for applying codeAction to the current buffer.
nmap <leader>ac  <Plug>(coc-codeaction)
" Apply AutoFix to problem on the current line.
nmap <leader>qf  <Plug>(coc-fix-current)

" Map function and class text objects
" NOTE: Requires 'textDocument.documentSymbol' support from the language server.
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Remap <C-f> and <C-b> for scroll float windows/popups.
" Note coc#float#scroll works on neovim >= 0.4.3 or vim >= 8.2.0750
nnoremap <nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
nnoremap <nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
inoremap <nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
inoremap <nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"

" " Use CTRL-S for selections ranges.
" " Requires 'textDocument/selectionRange' support of language server.
" nmap <silent> <C-s> <Plug>(coc-range-select)
" xmap <silent> <C-s> <Plug>(coc-range-select)

" Add `:Format` command to format current buffer.
command! -nargs=0 Format :call CocAction('format')

" Add `:Fold` command to fold current buffer.
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" Add `:OR` command for organize imports of the current buffer.
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Add (Neo)Vim's native statusline support.
" NOTE: Please see `:h coc-status` for integrations with external plugins that
" provide custom statusline: lightline.vim, vim-airline.
" set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" Mappings for CoCList
" Show all diagnostics.
nnoremap <silent><nowait> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions.
nnoremap <silent><nowait> <space>e  :<C-u>CocList extensions<cr>
" Show commands.
nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document.
nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols.
nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list.
nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>

""deoplete
"let g:deoplete#enable_at_startup = 1
"
""neocomplcache settings
"call deoplete#custom#option('camel_case', v:true)
"call deoplete#custom#option('smartcase', v:false)
"
"let g:deoplete#omni_patterns = {}
"call deoplete#custom#option('omni_patterns', {
"\ 'complete_method': 'omnifunc',
"\ 'terraform': '[^ *\t"{=$]\w*',
"\})
"
"let g:deoplete#sources#rust#racer_binary = $HOME . "/.cargo/bin/racer"
"let g:deoplete#sources#rust#rust_source_path = $HOME . "/git/github.com/rust-lang/rust"
"
""lsp
"if executable('terraform-lsp')
"    au User lsp_setup call lsp#register_server({
"        \ 'name': 'terraform-ls',
"        \ 'cmd': {server_info->['terraform-ls']},
"        \ 'whitelist': ['terraform'],
"        \ })
"endif
"if executable('gopls')
"    au User lsp_setup call lsp#register_server({
"        \ 'name': 'gopls',
"        \ 'cmd': {server_info->['gopls']},
"        \ 'whitelist': ['go'],
"        \ })
"endif


"push C-a to toggle spell check
nnoremap <silent> <C-a> :setl spell!<Return>

"key-mapping for edit vimrc
nnoremap <silent> <Space>ev  :<C-u>tabedit $MYVIMRC<CR>
nnoremap <silent> <Space>ee  :<C-u>edit $MYVIMRC<CR>
nnoremap <silent> <Space>eg  :<C-u>edit $MYGVIMRC<CR>
nnoremap <silent> <Space>ea  :source $MYVIMRC<Return>

augroup MKDUnFold
  autocmd!
  autocmd FileType markdown setl nofoldenable
augroup END

nnoremap <C-h> :<C-u>vertical help<Space>

"replace shortcut
nnoremap // :<C-u>%s/
vnoremap // :s/
nnoremap ? :<C-u>let @/ = ""<CR>

"quickrun.vim settings
if !exists('g:quickrun_config')
  let g:quickrun_config = {}
endif
let g:quickrun_config = {'_': { 'split': 'vertical rightbelow', 'runner': 'vimproc:updatetime=1'}}
let g:quickrun_config.markdown = {'exec' : ['markdown.pl %s > /tmp/__markdown.html','open /tmp/__markdown.html']}
"let g:quickrun_config.markdown = {'exec' : ['pandoc -f markdown -t html -o /tmp/markdown.html %s', 'open /tmp/markdown.html']}
let g:quickrun_config.actionscript = {'exec' : ['mxmlc -output /tmp/__as.swf -default-background-color 0xFFFFFF %s', 'open /tmp/__as.swf']}
let g:quickrun_config.coffee = {'command': 'coffee'}

"split shortcut
nnoremap <silent> <C-w>l <C-w>l:call <SID>Goodwidth()<Cr>
nnoremap <silent> <C-w>h <C-w>h:call <SID>Goodwidth()<Cr>

nnoremap sl <C-w>l:call <SID>Goodwidth()<Cr>
nnoremap sh <C-w>h:call <SID>Goodwidth()<Cr>
nnoremap sj <C-w>j:call <SID>Goodwidth()<Cr>
nnoremap sk <C-w>k:call <SID>Goodwidth()<Cr>
nnoremap sL <C-w>L
nnoremap sH <C-w>H
nnoremap sJ <C-w>J
nnoremap sK <C-w>K
nnoremap ss <C-w>=

"auto adjust a split window width
"http://vim-users.jp/2009/07/hack42/
function! s:Goodwidth()
  if winwidth(0) < 84
    vertical resize 90
  endif
endfunction

"tab shortcut
nnoremap <silent> tn :tabn<Cr>
nnoremap <silent> tp :tabp<Cr>
nnoremap <silent> tb :tabp<Cr>
nnoremap <silent> te :tabe<Cr>

"q -> C-o
nnoremap q <C-o>
nnoremap } <C-]>
nnoremap ' <C-]>

"super jump
nnoremap H 5h
nnoremap L 5l
nnoremap J <C-f>
nnoremap K <C-b>

"C-r U"
nnoremap U <C-r>

", <$
nnoremap , <<
nnoremap . >>

"; dd
nnoremap ; dd

"yj
nnoremap yj yyp

nnoremap m :<C-u>call append(expand('.'), '')<Cr>jj
nnoremap M k:<C-u>call append(expand('.'), '')<Cr>jj

"- gg=G
nnoremap - gg=G
vnoremap - =

" smartword
map ,w  <Plug>(smartword-w)
map ,b  <Plug>(smartword-b)
map ,e  <Plug>(smartword-e)
map ,ge <Plug>(smartword-ge)

" unite.vim {{{
function! s:SorahFileRec()
  if match(system("git show-ref HEAD"), "^fatal: Not a git repository") == 0
    Unite -start-insert file_rec
  else
    Unite -start-insert file_rec/git
  endif
endfunction

nnoremap <C-z> :<C-u>call <SID>SorahFileRec()<Cr>
nnoremap <C-x> :<C-u>Unite -start-insert outline<Cr>
nnoremap <C-s> :<C-u>Unite -start-insert tab<Cr>
nnoremap <C-c> :<C-u>Unite -start-insert ghq<Cr>
command! Gcd Unite -start-insert ghq

" unite-neco {{{
let s:unite_source = {'name': 'neco'}

function! s:unite_source.gather_candidates(args, context)
  let necos = [
        \ "~(-'_'-) goes right",
        \ "~(-'_'-) goes right and left",
        \ "~(-'_'-) goes right quickly",
        \ "~(-'_'-) skips right",
        \ "~(-'_'-)  -8(*'_'*) go right and left",
        \ "(=' .' ) ~w",
        \ ]
  return map(necos, '{
        \ "word": v:val,
        \ "source": "neco",
        \ "kind": "command",
        \ "action__command": "Neco " . v:key,
        \ }')
endfunction

"function! unite#sources#locate#define()
"  return executable('locate') ? s:unite_source : []
"endfunction
call unite#define_source(s:unite_source)
" }}}

" unite-evalruby {{{
let s:unite_source = {
      \ 'name': 'evalruby',
      \ 'is_volatile': 1,
      \ 'required_pattern_length': 1,
      \ 'max_candidates': 30,
      \ }

function! s:unite_source.gather_candidates(args, context)
  if a:context.input[-1:] == '.'
    let methods = split(
          \ unite#util#system(printf('ruby -e "puts %s.methods"', a:context.input[:-2])),
          \ "\n")
    call map(methods, printf("'%s' . v:val", a:context.input))
  else
    let methods = [a:context.input]
  endif
  return map(methods, '{
        \ "word": v:val,
        \ "source": "evalruby",
        \ "kind": "command",
        \ "action__command": printf("!ruby -e \"p %s\"", v:val),
        \ }')
endfunction

call unite#define_source(s:unite_source)
"}}}

" }}}

"rb
if has('mac') && !exists('g:sorah_vimrc_loaded')
  let $PATH=$HOME."/.rbenv/shims:".$PATH
  let $PATH=$HOME."/.rbenv/bin:".$PATH
  let $PATH=$HOME."/rubies/bin:".$PATH
endif

set vb t_vb=


"easy to save
nnoremap W :<C-u>w<Cr>
nnoremap <Space> :<C-u>w<Cr>
nnoremap V :<C-u>vsp<Cr>
nnoremap Q :<C-u>q<Cr>
nnoremap e :<C-u>tabe<Cr>

"mv editing file
function! g:MvEditingFile(new_file_name)
  call system("mv".expand('%')." ".a:new_file_name)
  e a:new_file_name
endfunction
command! -nargs=1 Rename call g:MvEditingFile(<f-args>)

"chdir to now dir
"http://vim-users.jp/2009/09/hack69/
command! -nargs=? -complete=dir -bang CD  call s:ChangeCurrentDir('<args>', '<bang>')
command! GitCd  call s:CdGitRoot()

function! s:ChangeCurrentDir(directory, bang)
  if a:directory == ''
    lcd %:p:h
  else
    execute 'lcd' . a:directory
  endif

  if a:bang == ''
    pwd
  endif
endfunction

function! s:CdGitRoot()
  let orig_dir = getcwd()
  execute 'lcd ' . fnamemodify(expand('%'),':p:h')
  let l:dir = system("git rev-parse --show-toplevel")
  execute 'lcd ' . orig_dir
  if match(l:dir, "^fatal: Not a") == -1
    execute 'lcd ' . l:dir
  endif
endfunction

nnoremap <silent> <Leader>cd :<C-u>CD!<CR>
nnoremap <silent> <Space>cd :<C-u>GitCd<CR>


" http://vim-users.jp/2009/11/hack104/
vnoremap <silent> * "vy/\V<C-r>=substitute(escape(@v,'\/'),"\n",'\\n','g')<CR><CR>

" smartinput
call smartinput#clear_rules()
call smartinput#define_default_rules()

call smartinput#map_to_trigger('i', '<Bar>', '<Bar>', '<Bar>')
call smartinput#map_to_trigger('i', '<Space>', '<Space>', '<Space>')
call smartinput#map_to_trigger('i', '(', '(', '(')
call smartinput#map_to_trigger('i', '{', '{', '{')
call smartinput#map_to_trigger('i', "'", "'", "'")

call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'],
                           \ 'at': '\<do\>\( |.*|\)\?\%#'.
                           \ '\|'. '^\s*\(if\|unless\|class\|module\|def\) .*\%#$'.
                           \ '\|'. '^\s*def .\+(.*\%#.*)$',
                           \ 'char': "<Enter>", 'input': '<End><Enter>end<Esc>O'})

call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'],
                           \ 'at': '\(\<do\>\|{\)\%#',
                           \ 'char': "<Bar>", 'input': ' <Bar><Bar><Esc>i'})
call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'],
                           \ 'at': '\(\<do\>\|{\) \%#',
                           \ 'char': "<Bar>", 'input': '<Bar><Bar><Esc>i'})
call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'],
                           \ 'at': '\<do\> |.*\%#|',
                           \ 'char': "<Enter>", 'input': '<Esc>oend<Esc>O'})
call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'],
                           \ 'at': '\(\<do\>\|{\) |.*\%#|',
                           \ 'char': "<Bar>", 'input': '<Right><Space>'})



call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'],
                           \ 'at': '^\s*\(require\|load\|require_relative\)\%#$',
                           \ 'char': "<Space>", 'input': " ''<Left>"})
call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'],
                           \ 'at': '^\s*\(require\|load\|require_relative\) ' . "'" . '\%#' . "'$",
                           \ 'char': "<Space>", 'input': ""})
call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'],
                           \ 'at': '^\s*\(require\|load\|require_relative\) ' . "'" . '\%#' . "'$",
                           \ 'char': "'", 'input': ""})
call smartinput#define_rule({'filetype': ['ruby', 'ruby.rspec'], 'syntax': ['Constant'],
                           \ 'at': '^\s*\(require\|load\|require_relative\) .\+\%#',
                           \ 'char': "<Enter>", 'input': "<Esc>o"})

call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*\(describe\|context\)\%#$',
                           \ 'char': "<Space>", 'input': ' "" do<Left><Left><Left><Left>'})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*\(describe\|context\) .*\%#.* do$',
                           \ 'char': "<Enter>", 'input': "<Esc>A<Enter>end<Esc>O"})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*it\%#$',
                           \ 'char': "<Space>", 'input': ' ""<Left>'})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*\(it\|specify\) "\%#"',
                           \ 'char': "{", 'input': '<Esc>A<BS><BS>{  }<Left><Left>'})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*\(it\|specify\) ".*\%#.*"$'.
                           \ '\|'. '^\s*\(it\|specify\) ".*"\%#$',
                           \ 'char': "<Enter>", 'input': '<Esc>A do<Enter>end<Esc>O'})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*\(it\|specify\).*do\r\?\n\s*\(context\|describe\)\%#$',
                           \ 'char': "<Space>", 'input': '<Esc>k:<C-u>.s/ do$//<Cr>j<<jddkA "" do<Left><Left><Left><Left>'})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*\(it\|specify\).*do\r\?\n\s*\(it\|specify\)\%#$',
                           \ 'char': "<Space>", 'input': '<Esc>k:<C-u>.s/ do$//<Cr>j<<jddkA ""<Left>'})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*\(it\|specify\).*do\r\?\n\s*\(let\|before\|after\|around\|subject\)\%#$',
                           \ 'char': "<Space>", 'input': '<esc>k:<c-u>.s/ do$//<cr>j<<jddka '})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*let\%#$',
                           \ 'char': "(", 'input': '(:'})
call smartinput#define_rule({'filetype': ['ruby.rspec'],
                           \ 'at': '^\s*\(before\|after\|around\|subject\)\%#$',
                           \ 'char': "<Enter>", 'input': ' do<Enter>end<Esc>O'})

" eskk
imap <C-j> <Plug>(eskk:toggle)
if filereadable("/usr/share/skk/SKK-JISYO.L")
  let g:eskk#large_dictionary = {
  \ 'path': "/usr/share/skk/SKK-JISYO.L",
  \ 'sorted': 1,
  \ 'encoding': 'euc-jp',
  \}
endif

"compl
"inoremap <expr> ] searchpair('\[', '', '\]', 'nbW', 'synIDattr(synID(line("."), col("."), 1), "name") =~? "String"') ? ']' : "\<C-n>"

"ew
function! s:VimRcWriteEdit()
  write
  edit
endfunction
command! WriteEdit call s:VimRcWriteEdit()
cabbrev we WriteEdit

" metarw
call metarw#define_wrapper_commands(1)

" rspec
augroup UjihisaRSpec
  autocmd!
  autocmd BufWinEnter,BufNewFile *_spec.rb set filetype=ruby.rspec
augroup END

nnoremap <Leader>q q:

" one-line git blaming https://gist.github.com/4054621"{{{
function! s:git_blame_info_dict(filename,line_num)
  let lines = split(system(printf('git blame -w -L%d,%d --line-porcelain %s'
    \ ,a:line_num,a:line_num,a:filename)),"\n")
  if len(lines) == 13
    let dict = {
    \ 'hash' : split(lines[0],' '),
    \ 'author' : matchstr(lines[1],'author \zs.*'),
    \ 'author-mail' : matchstr(lines[2],'author-mail \zs.*'),
    \ 'author-time' : matchstr(lines[3],'author-time \zs.*'),
    \ 'author-tz' : matchstr(lines[4],'author-tz \zs.*'),
    \ 'committer' : matchstr(lines[5],'committer \zs.*'),
    \ 'committer-mail' : matchstr(lines[6],'committer-mail \zs.*'),
    \ 'committer-time' : matchstr(lines[7],'committer-time \zs.*'),
    \ 'committer-tz' : matchstr(lines[8],'committer-tz \zs.*'),
    \ 'summary' : matchstr(lines[9],'summary \zs.*'),
    \ 'previous' : split(matchstr(lines[10],'previous \zs.*'),' '),
    \ 'filename' : matchstr(lines[11],'filename \zs.*'),
    \ 'line' : lines[12],
    \ }
    let dict['author'] = dict['author'] ==# 'Not Committed Yet' ? '' : dict['author']
    let dict['author-mail'] = dict['author-mail'] ==# '<not.committed.yet>' ? '' : dict['author-mail']
    let dict['committer'] = dict['committer'] ==# 'Not Committed Yet' ? '' : dict['committer']
    let dict['committer-mail'] = dict['committer-mail'] ==# '<not.committed.yet>' ? '' : dict['committer-mail']
    return dict
  else
    return {}
  endif
endfunction
function! s:git_blame_info(filename,line_num)
  let ex_fname = fnamemodify(a:filename,':p')
  let ex_fname_dir = fnamemodify(a:filename,':p:h')
  let orig_dir = getcwd()
  execute 'lcd ' . ex_fname_dir
  let result = s:git_blame_info_dict(ex_fname,a:line_num)
  execute 'lcd ' . orig_dir
  if empty(result)
    return 'null'
  else
    return printf('[%s][%s] %s',result.hash[0][:6],result.committer,result.summary)
  endif
endfunction

function! s:git_blame_show(filename,line_num)
  let ex_fname = fnamemodify(a:filename,':p')
  let ex_fname_dir = fnamemodify(a:filename,':p:h')
  let tmp_dir = getcwd()
  execute 'cd ' . ex_fname_dir
  let result = s:git_blame_info_dict(ex_fname,a:line_num)
  execute 'cd ' . tmp_dir
  if !empty(result)
    vertical new
    call append(0, split(system("git show " . shellescape(result.hash[0])), '\n'))
    setf git
    call setpos('.', getpos('g'))
  endif
endfunction

nnoremap <C-g>  :echo <SID>git_blame_info(expand('%'),line('.'))<CR>
nnoremap <silent><C-d>  :call <SID>git_blame_show(expand('%'),line('.'))<CR>
"}}}

" Go
let g:go_fmt_autosave = 1
let g:go_doc_keywordprg_enabled = 0
let g:godef_split = 0

function! s:sorah_go_setup()
  setlocal tabstop=4 softtabstop=4 shiftwidth=4 noexpandtab
endfunction

augroup SorahGoSetup
  autocmd!
  autocmd BufWinEnter,BufNewFile *.go call s:sorah_go_setup()
augroup END

" cf. http://github.com/ujihisa/config/blob/4cd4f32695917f95e9657feb07b73d0cafa6a60c/_vimrc#L310
function! s:CRuby_setup()
  setlocal tabstop=8 softtabstop=4 shiftwidth=4 noexpandtab
  syntax keyword cType VALUE ID RUBY_DATA_FUNC BDIGIT BDIGIT_DBL BDIGIT_DBL_SIGNED ruby_glob_func
  syntax keyword cType rb_global_variable
  syntax keyword cType rb_classext_t rb_data_type_t
  syntax keyword cType rb_gvar_getter_t rb_gvar_setter_t rb_gvar_marker_t
  syntax keyword cType rb_encoding rb_transcoding rb_econv_t rb_econv_elem_t rb_econv_result_t
  syntax keyword cType RBasic RObject RClass RFloat RString RArray RRegexp RHash RFile RRational RComplex RData RTypedData RStruct RBignum
  syntax keyword cType st_table st_data
  syntax match   cType display "\<\(RUBY_\)\?T_\(OBJECT\|CLASS\|MODULE\|FLOAT\|STRING\|REGEXP\|ARRAY\|HASH\|STRUCT\|BIGNUM\|FILE\|DATA\|MATCH\|COMPLEX\|RATIONAL\|NIL\|TRUE\|FALSE\|SYMBOL\|FIXNUM\|UNDEF\|NODE\|ICLASS\|ZOMBIE\)\>"
  syntax keyword cStatement ANYARGS NORETURN PRINTF_ARGS
  syntax keyword cStorageClass RUBY_EXTERN
  syntax keyword cOperator IMMEDIATE_P SPECIAL_CONST_P BUILTIN_TYPE SYMBOL_P FIXNUM_P NIL_P RTEST CLASS_OF
  syntax keyword cOperator INT2FIX UINT2NUM LONG2FIX ULONG2NUM LL2NUM ULL2NUM OFFT2NUM SIZET2NUM SSIZET2NUM
  syntax keyword cOperator NUM2LONG NUM2ULONG FIX2INT NUM2INT NUM2UINT FIX2UINT
  syntax keyword cOperator NUM2LL NUM2ULL NUM2OFFT NUM2SIZET NUM2SSIZET NUM2DBL NUM2CHR CHR2FIX
  syntax keyword cOperator NEWOBJ OBJSETUP CLONESETUP DUPSETUP
  syntax keyword cOperator PIDT2NUM NUM2PIDT
  syntax keyword cOperator UIDT2NUM NUM2UIDT
  syntax keyword cOperator GIDT2NUM NUM2GIDT
  syntax keyword cOperator FIX2LONG FIX2ULONG
  syntax keyword cOperator POSFIXABLE NEGFIXABLE
  syntax keyword cOperator ID2SYM SYM2ID
  syntax keyword cOperator RSHIFT BUILTIN_TYPE TYPE
  syntax keyword cOperator RB_GC_GUARD_PTR RB_GC_GUARD
  syntax keyword cOperator Check_Type
  syntax keyword cOperator StringValue StringValuePtr StringValueCPtr
  syntax keyword cOperator SafeStringValue Check_SafeStr
  syntax keyword cOperator ExportStringValue
  syntax keyword cOperator FilePathValue
  syntax keyword cOperator FilePathStringValue
  syntax keyword cOperator ALLOC ALLOC_N REALLOC_N ALLOCA_N MEMZERO MEMCPY MEMMOVE MEMCMP
  syntax keyword cOperator RARRAY RARRAY_LEN RARRAY_PTR RARRAY_LENINT
  syntax keyword cOperator RBIGNUM RBIGNUM_POSITIVE_P RBIGNUM_NEGATIVE_P RBIGNUM_LEN RBIGNUM_DIGITS
  syntax keyword cOperator Data_Wrap_Struct Data_Make_Struct Data_Get_Struct
  syntax keyword cOperator TypedData_Wrap_Struct TypedData_Make_Struct TypedData_Get_Struct

  syntax keyword cConstant Qtrue Qfalse Qnil Qundef
  syntax keyword cConstant IMMEDIATE_MASK FIXNUM_FLAG SYMBOL_FLAG

  " for bignum.c
  syntax keyword cOperator BDIGITS BIGUP BIGDN BIGLO BIGZEROP
  syntax keyword cConstant BITPERDIG BIGRAD DIGSPERLONG DIGSPERLL BDIGMAX
endfunction

function! s:CRuby_ext_setup()
  let dirname = expand("%:h")
  let extconf = dirname . "/extconf.rb"
  if filereadable(extconf)
    call s:CRuby_setup()
  endif
endfunction

augroup CRuby
  autocmd!
  autocmd BufWinEnter,BufNewFile ~/git/github.com/ruby/ruby/*.[chy] call s:CRuby_setup()
  autocmd BufWinEnter,BufNewFile ~/git/rubies/ruby/*.[chy] call s:CRuby_setup()
  autocmd BufWinEnter,BufNewFile ~/Dropbox/git/github.com/ruby/ruby/*.[chy] call s:CRuby_setup()
  autocmd BufWinEnter,BufNewFile ~/work/ruby/*.[chy] call s:CRuby_setup()
  autocmd BufWinEnter,BufNewFile *.{c,cc,cpp,h,hh,hpp} call s:CRuby_ext_setup()
augroup END



let g:rails_no_syntax = '1'

"quickrun customize for competitive programming
function! s:CompetitiveSetup()
  let b:input_tmp = tempname()
  nnoremap <buffer> <Leader>r :<C-u>exe "QuickRun <".b:input_tmp<Cr>
  exe "rightbelow vsplit ".b:input_tmp
endfunction
command! QuickComp call s:CompetitiveSetup()

" Show syntax higroup on cursor
map <C-o> :echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<'
\ . synIDattr(synID(line("."),col("."),0),"name") . "> lo<"
\ . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">"<CR>

" Rust
let g:rustfmt_autosave = 1
let g:racer_experimental_completer = 1 

if executable('rust-analyzer')
  call ale#linter#Define('rust', {
  \   'name': 'rust-analyzer',
  \   'lsp': 'stdio',
  \   'executable': 'rust-analyzer',
  \   'command': '%e',
  \   'project_root': '.',
  \})
  au User lsp_setup call lsp#register_server({
      \ 'name': 'rust-analyzer',
      \ 'cmd': {server_info->['rust-analyzer']},
      \ 'whitelist': ['rust'],
      \ })
endif

function! s:sorah_rust_setup()
  setlocal tabstop=4 softtabstop=4 shiftwidth=4
endfunction

augroup SrhRustSetup
  autocmd!
  autocmd BufWinEnter,BufNewFile *.rs call s:sorah_rust_setup()
augroup END



" Terraform
let g:terraform_fmt_on_save=1

" Syntastic/Ale
let g:ale_linters_ignore = {
\  'ruby': ['rubocop'],
\ }

let g:tsuquyomi_disable_quickfix = 1

" jsonnet
function s:sorah_jsonnet_setup()
  setl autoindent
  setl nocindent
endfunction

augroup SrhJsonnetSetup
  autocmd!
  autocmd BufWinEnter,BufNewFile *.jsonnet call s:sorah_jsonnet_setup()
  autocmd BufWinEnter,BufNewFile *.libsonnet call s:sorah_jsonnet_setup()
augroup END



"read other vimrc files
if filereadable($VIMFILES."/other/private.vim")
  source $VIMFILES/other/private.vim
endif
if filereadable($HOME."/.vimrc.local")
  source $HOME/.vimrc.local
endif


let g:sorah_vimrc_loaded = 1
