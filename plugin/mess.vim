let s:PROJ_DIR = $HOME . "/.proj_db"
let s:LOG_TAG = "[DB] "
let s:DEBUG = 0
let s:MAX_PROJECT_NUM = 100
let s:plugin_root_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h')
python3 << EOF
import sys, os.path
import vim
plugin_root_dir = vim.eval('s:plugin_root_dir')
python_root_dir = os.path.normpath(os.path.join(plugin_root_dir, '..', 'python'))
sys.path.insert(0, python_root_dir)
import mess
EOF

function! s:LOGD(msg)
  if s:DEBUG
    echom s:LOG_TAG . a:msg
  endif
endfunction

function! s:LOGI(msg)
  echom s:LOG_TAG . a:msg
endfunction

function! EnsureDirExists(inDir)
  if !isdirectory(a:inDir)
    call mkdir(a:inDir, 'p')
    echom "Created directory: " . a:inDir
  endif
endfunction

"return: type: dict
"        value: <k, v> = <projId, projName>
function! mess#GetProjects()
  let ret = {} "empty dict
  if isdirectory(s:PROJ_DIR)
    for item in split(glob(s:PROJ_DIR . "/*"), "\n") "~/.proj_db/1, ~/.proj_db/2
      let projId = split(item, '/')[-1] "file stem
      let projName = readfile(item . "/name")[0] "~/.proj_db/<id>/name
      let ret[projId] = projName
    endfor
  else
    echom s:LOG_TAG . "No project has been created. You may start with 'db init <project_name>'"
  endif
  return ret
endfunction

"return: none
function! mess#PrintProjects()
  let projects = mess#GetProjects()
  for k in keys(projects)
    if $SELECT_PROJECT_DB ==# k
      echom "* " . k . " - " . projects[k]
    else
      echom "  " . k . " - " . projects[k]
    endif
  endfor
endfunction

"return: type: String,
"        value: selected project id, or "-1" if none
function! mess#SelectProject()
  call mess#PrintProjects()
  if len(mess#GetProjects()) ==# 0
    call s:LOGD("no avail projects")
    return "-1"
  endif
  call inputsave()
  let projId = input('Enter Project Id: ')
  call inputrestore()
  if projId ==# ""
    call s:LOGD("WARN: selected none")
    return "-1"
  endif
  echo "\n"
  call s:LOGD(s:LOG_TAG . "Your input is [" . projId . "]")
  let projectIds = keys(mess#GetProjects())
  if -1 ==# index(projectIds, projId)
    let projId = "-1"
    call s:LOGD("ERROR: Invalid project id: " . projId)
  else
    call s:LOGD("Selected project " . projId)
  endif
  return projId
endfunction

"return: none
function! mess#OnProjectSelected(selectedProj)
  call s:LOGD("a:selectedProj is [" . a:selectedProj . "]")
  if "-1" ==# a:selectedProj
    call s:LOGD("invalid a:selectedProj [" . a:selectedProj . "]")
    return
  else
    "change env var if necessary
    if $SELECT_PROJECT_DB !=# a:selectedProj
      call s:LOGD("env var SELECT_PROJECT_DB is changed from [" . $SELECT_PROJECT_DB . "] -> [" . a:selectedProj . "]")
      let $SELECT_PROJECT_DB = a:selectedProj
    else
      call s:LOGD("env var SELECT_PROJECT_DB remain unchanged [" . $SELECT_PROJECT_DB . "]")
    endif
    "for cscope
    call mess#LoadCscopeData()
  endif
endfunction

function! mess#LoadCscopeData()
  "map keys
  nnoremap <silent> <F3> :call fzf#run({'source': 'cat $HOME/.proj_db/$SELECT_PROJECT_DB/cscope.files', 'sink': 'edit'})<CR>
  let csData = expand("$HOME/.proj_db/$SELECT_PROJECT_DB/cscope.out")
  call s:LOGD(csData)
  if filereadable(csData)
    " for M$ compatible
    cd $HOME
    echom "Loading " . csData
    cs add .proj_db/$SELECT_PROJECT_DB/cscope.out
    cd -
  else
    echom "cscope files not found"
  endif
endfunction

function! mess#AddPath(inDir)
  if $SELECT_PROJECT_DB ==# -1 || $SELECT_PROJECT_DB ==# ""
    echom "no project selected"
    return
  endif
  let SESSION_DIR = s:PROJ_DIR . "/" . $SELECT_PROJECT_DB
  let PROJ_FILELIST = SESSION_DIR . "/projlist"
python3 << EOF
import vim
import os, os.path
fileList = vim.eval("PROJ_FILELIST")
newLines = []
inDir = os.path.realpath(vim.eval("a:inDir"))
if os.path.isfile(fileList):
    with open(fileList, "r") as fd:
        lines = fd.readlines()
        bHandled = False
        for line in lines:
            if (inDir + "/").startswith(line.strip()+"/"):
                newLines.append(line.strip())
                print("[%s] already in project as [%s]" % (inDir, line.strip()))
                bHandled = True
            elif (line.strip()+"/").startswith((inDir + "/")):
                print("Override [%s] with newly added [%s]" % (line.strip(), inDir))
                newLines.append(inDir)
                bHandled = True
            else:
                newLines.append(line.strip())
        else:
            if not bHandled:
                print("Finally add [%s] into project" % inDir)
                newLines.append(inDir)
if len(newLines) == 0:
    print("Add first dir [%s] into project" % inDir)
    newLines.append(inDir)
with open(fileList, "w") as fd:
    for line in set(newLines):
        fd.write(line + "\n")
EOF
endfunction

function! mess#RemovePath(inDir)
  if $SELECT_PROJECT_DB ==# -1 || $SELECT_PROJECT_DB ==# ""
    echom "no project selected"
    return
  endif
  let SESSION_DIR = s:PROJ_DIR . "/" . $SELECT_PROJECT_DB
  let PROJ_FILELIST = SESSION_DIR . "/projlist"
python3 << EOF
import vim
import os, os.path
fileList = vim.eval("PROJ_FILELIST")
newLines = []
inDir = os.path.realpath(vim.eval("a:inDir"))
if os.path.isfile(fileList):
    with open(fileList, "r") as fd:
        lines = fd.readlines()
        bHandled = False
        for line in lines:
            if (inDir + "/") == (line.strip()+"/"):
                print("Path [%s] removed" % inDir)
                bHandled = True
            else:
                newLines.append(line.strip())
                #if len(newLines) == 0:
                #    print("Add first dir [%s] into project" % inDir)
if not bHandled:
    print("Path [%s] not in project list, not removed" % inDir)
with open(fileList, "w") as fd:
    for line in set(newLines):
        fd.write(line + "\n")
EOF
endfunction

"return: none
function! CreateProject(inName)
  "arg check
  if a:inName ==# ""
    call s:LOGD("project name can not be blank")
    return
  endif
  let projects = mess#GetProjects()
  "ensure project name not taken
  if -1 !=# index(values(projects), a:inName)
    echom expand("project '" . a:inName . "' already exists")
    return
  endif
  let projId = 1
  while v:true
    if -1 ==# index(keys(projects), "" . projId)
      break
    endif
    let projId += 1
    if projId > s:MAX_PROJECT_NUM
      let projId = -1
      break
    endif
  endwhile
  if projId !=# -1
    "create project
    call EnsureDirExists(s:PROJ_DIR . "/" . projId)
    call writefile([ a:inName ] , s:PROJ_DIR . "/" . projId . "/name")
  endif
endfunction

function! mess#ShowPath()
  if $SELECT_PROJECT_DB ==# -1 || $SELECT_PROJECT_DB ==# ""
    echom "no project selected"
    return
  endif
  let SESSION_DIR = s:PROJ_DIR . "/" . $SELECT_PROJECT_DB
  let PROJ_FILELIST = SESSION_DIR . "/projlist"
  echom "---------------List of Project Folder------------------"
  for line in readfile(fnameescape(PROJ_FILELIST))
    echom line
  endfor
  echom "-------------------------------------------------------"
endfunction

function! mess#CleanProject()
  if $SELECT_PROJECT_DB ==# -1 || $SELECT_PROJECT_DB ==# ""
    echom "no project selected"
    return
  endif
  let SESSION_DIR = s:PROJ_DIR . "/" . $SELECT_PROJECT_DB
  let PROJ_FILELIST = SESSION_DIR . "/projlist"
  echom "Preparing to clean up project " . SELECT_PROJECT_DB
endfunction

" Commands {{{1
command! -nargs=0 DB call mess#PrintProjects()

" Key mapping
nnoremap <silent> <F10> :call mess#OnProjectSelected(mess#SelectProject())<CR>

" init
" DO NOT load data automatically
"if $SELECT_PROJECT_DB !=# ""
"  call mess#LoadCscopeData()
"endif

function! BuildIndex()
  python3 mess.run()
endfunction
