let s:PROJ_DIR = $HOME . "/.proj_db"
let s:LOG_TAG = "[DB] "
let s:DEBUG = 0
let s:MAX_PROJECT_NUM = 100

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
function! GetProjects()
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
function! PrintProjects()
  let projects = GetProjects()
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
  call PrintProjects()
  if len(GetProjects()) ==# 0
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
  let projectIds = keys(GetProjects())
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
  if "-1" !=# a:selectedProj
    "change env var if necessary
    if $SELECT_PROJECT_DB !=# a:selectedProj
      call s:LOGD("env var SELECT_PROJECT_DB is changed from [" . $SELECT_PROJECT_DB . "] -> [" . a:selectedProj . "]")
      let $SELECT_PROJECT_DB = a:selectedProj
    else
      call s:LOGD("env var SELECT_PROJECT_DB remain unchanged [" . $SELECT_PROJECT_DB . "]")
    endif
    "for cscope
    let csData = expand("$HOME/.proj_db/$SELECT_PROJECT_DB/cscope.out")
    call s:LOGD(csData)
    if filereadable(csData)
      " for M$ compatible
      cd $HOME
      echom "Loading " . csData
      cs add .proj_db/$SELECT_PROJECT_DB/cscope.out
      cd -
    else
      echom "cscope index files not found"
    endif
  else
    call s:LOGD("invalid a:selectedProj [" . a:selectedProj . "]")
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
endfunction

"return: none
function! CreateProject(inName)
  "arg check
  if a:inName ==# ""
    call s:LOGD("project name can not be blank")
    return
  endif
  let projects = GetProjects()
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

function! Demo()
  call inputsave()
  let name = input('Enter Project Id: ')
  call inputrestore()
  echo "\n"
  echom s:LOG_TAG . "Your input is " . name
  return name
endfunction