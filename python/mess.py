#-------------------------------------------------------------------------------
#                                  imports
#-------------------------------------------------------------------------------
import urllib, urllib.request
import json
import os, subprocess
import platform
import vim

#-------------------------------------------------------------------------------
#                             constants & globals
#-------------------------------------------------------------------------------
CURRENT_DIR = os.getcwd()
PROJ_DIR = os.path.join(os.path.expanduser("~"),".proj_db")
osinfo = platform.system()

SELECT_PROJECT_DB = None #main flag
SESSION_DIR = None
SESSION_NAME = None
PROJ_FILELIST = None

#-------------------------------------------------------------------------------
#                                 class
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#                                 function
#-------------------------------------------------------------------------------

def _get(url):
    return urllib.request.urlopen(url, None, 5).read().strip().decode()

def _get_country():
    try:
        ip = _get('http://ipinfo.io/ip')
        json_location_data = _get('http://api.ip2country.info/ip?%s' % ip)
        location_data = json.loads(json_location_data)
        return location_data['countryName']
    except Exception as e:
        print('Error in sample plugin (%s)' % e.msg)

def print_country():
    print('You seem to be in %s' % _get_country())

def envCheck():
    global SELECT_PROJECT_DB
    global SESSION_DIR
    global PROJ_FILELIST
    global SESSION_NAME
    SELECT_PROJECT_DB = vim.eval("$SELECT_PROJECT_DB")
    #SELECT_PROJECT_DB = os.getenv("SELECT_PROJECT_DB", None)
    if SELECT_PROJECT_DB and SELECT_PROJECT_DB != "-1":
        SESSION_DIR = os.path.join(PROJ_DIR, SELECT_PROJECT_DB)
        PROJ_FILELIST = os.path.join(SESSION_DIR, "projlist")
        with open(os.path.join(PROJ_DIR, SELECT_PROJECT_DB, "name")) as session_name:
            SESSION_NAME = session_name.readlines()[0].strip()
    else:
        SELECT_PROJECT_DB = None
        print("SELECT_PROJECT_DB not set")

def folder2file(inDir=None):
    import re
    outFileName = os.path.join(SESSION_DIR, "cscope.files")
    print("Searching ... \n [%s] >> [%s] ..." % (inDir, outFileName))
    p_white_list = re.compile(".*releasetools.*")
    p_black_list = re.compile(".*out/target.*")
    p_plus = re.compile(".*\.(c|cpp|cc|mk|xml|aidl|idl|java|py|sh|GNUMakefile|Makefile|h|hpp|hh)$")
    p_minus = re.compile(".*\.(git|svn).*")
    f = open(outFileName, "a")
    for (root, dirs, files) in os.walk(inDir):
        for afile in files:
            item = os.path.join(root, afile)
            if p_white_list.match(item):
                f.write("%s\n" % item)
                continue
            if p_black_list.match(item):
                continue
            if p_plus.match(item):
                if p_minus.match(item):
                    pass
                    #print("- %s" % item)
                else:
                    #print("+ %s" % item)
                    f.write("%s\n" % item)
    f.close()
    #theCmd = """ \
    #    ! -wholename "*.git*" -type f -regex ".*\.c$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.cpp$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.cc$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.mk$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.xml$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.aidl$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.java$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.py$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.sh$" \
    #-or ! -wholename "*.git*" -type f -regex ".*Makefile$" \
    #-or ! -wholename "*.git*" -type f -regex ".*\.h$" \
    #>> """


def folders2file(listfile):
    os.chdir(SESSION_DIR)
    if "Windows" == osinfo:
        os.system("del /f /q cscope.files*")
    elif "Linux" == osinfo:
        os.system("rm -f cscope.files*")
    elif "Darwin" == osinfo:
        os.system("rm -f cscope.files*")
    else:
        raise

    try:
        with open(listfile, "r") as fd:
            lines = fd.readlines()
            for line in lines:
                folder2file(line.strip())
    except IOError as e:
        print("I/O error ({0}):{1}".format(e.errno, e.strerror))
        raise
    except ValueError:
        print("ValueError")
        raise
    except:
        print("Unexpected error [%s]" % sys.exc_info()[0])
        raise

def addQuote(inFileName="cscope.files", outFileName="cscope.files.quoted"):
    os.chdir(SESSION_DIR)
    print("Quoting ...\n [%s] >> [%s] " % (inFileName, outFileName))
    fd = open(inFileName, "r")
    lines = fd.readlines()
    #print(lines)
    fd.close()
    newlines = []
    for line in lines:
        _line = line.rstrip()
        while os.path.islink(_line):
            _line = os.path.realpath(_line)
        if len(_line) > 249:
            print("File name tooooooo long! %s" % _line)
            continue
        if not os.path.isfile(_line):
            print("File invalid: %s" % _line)
            continue
        newlines.append('"' + _line + '"\n')
    #print(newlines)
    fd = open(outFileName, "w")
    fd.writelines(newlines)
    fd.close()

    return 0

def buildIndex(filename="cscope.files.quoted"):
    os.chdir(SESSION_DIR)
    if "Windows" == osinfo:
        os.system("del /f /q cscope.out cscope.out*")
        os.system("del /f tags")
    elif ("Linux" == osinfo or "Darwin" == osinfo):
        os.system("rm -fr cscope*out")
        os.system("rm -f tags")
    else:
        raise
    print("Cscope indexing ...\n [%s] >> [cscope.* ncscope.out]" % filename)
    theCmd = "cscope -bqC -i " + filename #-C to ignore case
    subprocess.check_call(theCmd, shell=True)

    return
    print("Ctags indexing ...\n [%s] >> [tags]" % PROJ_FILELIST)
    try:
        with open(PROJ_FILELIST, "r") as fd:
            lines = fd.readlines()
            for line in lines:
                theCmd = 'ctags --append=yes -R ' + line.strip() + ' -h .h.H.hh.hpp.hxx.h++.inc.def.cpp.c.java.mk'
                subprocess.check_call(theCmd, shell=True)
    except IOError as e:
        print("I/O error ({0}):{1}".format(e.errno, e.strerror))
        raise
    except ValueError:
        print("ValueError")
        raise
    except:
        print("Unexpected error [%s]" % sys.exc_info()[0])
        raise

def addQuote(inFileName="cscope.files", outFileName="cscope.files.quoted"):
    os.chdir(SESSION_DIR)
    print("Quoting ...\n [%s] >> [%s] " % (inFileName, outFileName))
    fd = open(inFileName, "r")
    lines = fd.readlines()
    #print(lines)
    fd.close()
    newlines = []
    for line in lines:
        _line = line.rstrip()
        while os.path.islink(_line):
            _line = os.path.realpath(_line)
        if len(_line) > 249:
            print("File name tooooooo long! %s" % _line)
            continue
        if not os.path.isfile(_line):
            print("File invalid: %s" % _line)
            continue
        newlines.append('"' + _line + '"\n')
    #print(newlines)
    fd = open(outFileName, "w")
    fd.writelines(newlines)
    fd.close()

    return 0

def run():
    envCheck()
    if not SELECT_PROJECT_DB:
        return
    folders2file(PROJ_FILELIST)
    addQuote()
    buildIndex()

