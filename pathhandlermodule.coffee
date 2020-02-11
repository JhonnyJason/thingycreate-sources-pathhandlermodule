pathhandlermodule = {name: "pathhandlermodule"}
############################################################
#region logPrintFunctions
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["pathhandlermodule"]?  then console.log "[pathhandlermodule]: " + arg
    return
olog = (o) -> log "\n" + ostr(o)
ostr = (o) -> JSON.stringify(o, null, 4)
print = (arg) -> console.log(arg)
#endregion

############################################################
#region modulesFromEnvironment
############################################################
#region node_modules
fs = require("fs-extra")
pathModule = require("path")
os = require "os"
exec = require("child_process").exec
#endregion

############################################################
utl = null
cfg = null
#endregion

############################################################
#region properties
############################################################
#region internalProperties
homedir = os.homedir()
thingyName = ""

############################################################
try specifics = require "./pathhandlerspecifics" catch err
#endregion

############################################################
#region exposedProperties
pathhandlermodule.homedir = homedir #directory
pathhandlermodule.userConfigPath = "" #file
pathhandlermodule.basePath = "" #directory
pathhandlermodule.thingyPath = "" #directory
pathhandlermodule.temporaryFilesPath = "" #directory
pathhandlermodule.recipesPath = ""
#endregion
#endregion

############################################################
pathhandlermodule.initialize = () ->
    log "pathhandlermodule.initialize"
    Object.assign(pathhandlermodule, specifics)
    
    utl = allModules.utilmodule
    cfg = allModules.configmodule
    await prepareUserConfigPath()
    return

############################################################
#region internalFunctions
execGitCheckPromise = (path) ->
    options = 
        cwd: path
    
    return new Promise (resolve, reject) ->
        callback = (error, stdout, stderr) ->
            if error then reject(error)
            if stderr then reject(new Error(stderr))
            resolve(stdout)
        exec("git rev-parse --is-inside-work-tree", options, callback)

prepareUserConfigPath = ->
    log "prepareUserConfigPath"
    filePath = resolveHomeDir(cfg.cli.userConfigPath)
    dirPath = pathModule.dirname(filePath)
    await fs.mkdirp(dirPath)
    pathhandlermodule.userConfigPath = filePath
    return

resolveHomeDir = (path) ->
    log "resolveHomeDir"
    if !path then return
    if path[0] == "~"
        path = path.replace("~", homedir)
    return path


############################################################
checkSomethingExists = (something) ->
    try
        await fs.lstat(something)
        return true
    catch err then return false

checkDirectoryExists = (path) ->
    try
        stats = await fs.lstat(path)
        return stats.isDirectory()
    catch err
        return false

checkDirectoryIsInGit = (path) ->
    try
        await execGitCheckPromise(path)
        return true
    catch err
        return false
#endregion

############################################################
#region exposedFunctions
pathhandlermodule.resolve = pathModule.resolve

pathhandlermodule.relative = pathModule.relative

pathhandlermodule.resolveHomeDir = resolveHomeDir

pathhandlermodule.checkDirectoryExists = checkDirectoryExists

############################################################
#region preparationFunctions
pathhandlermodule.prepareBasePath = (providedPath) ->
    log "pathhandlermodule.checkBase"
    
    if !providedPath then providedPath = cfg.userConfig.defaultThingyRoot
    
    providedPath = resolveHomeDir(providedPath)
    if pathModule.isAbsolute(providedPath)
        pathhandlermodule.basePath = providedPath
    else
        pathhandlermodule.basePath = pathModule.resolve(process.cwd(), providedPath)
    
    log "our basePath is: " + pathhandlermodule.basePath
    ##sadly this case has gone ;( - it lives on in this comment
    # pathhandlermodule.basePath = process.cwd()

    exists = await checkDirectoryExists(pathhandlermodule.basePath)

    if !exists
        throw new Error("Provided directory does not exist!")

    isInGit = await checkDirectoryIsInGit(pathhandlermodule.basePath)
    if isInGit
        throw new Error("Provided directory is already in a git subtree!")

pathhandlermodule.prepareTemporaryFilesPath = ->
    log "pathhandlermodule.prepareTemporaryFilesPath"
    pathhandlermodule.temporaryFilesPath = resolveHomeDir(cfg.userConfig.temporaryFiles)
    return

pathhandlermodule.prepareRecipesPath = ->
    log "pathhandlermodule.prepareRecipesPath"
    if !cfg.userConfig.recipesPath then cfg.userConfig.recipesPath = "~/.config/thingyBubble/recipes"
    pathhandlermodule.recipesPath = resolveHomeDir(cfg.userConfig.recipesPath)
    return
#endregion

############################################################
#region checkPathsExistence
pathhandlermodule.ensureDirectoryExists = (directory) ->
    log "pathhandlermodule.ensureDirectoryExists"
    directory = resolveHomeDir(directory)
    result = await fs.mkdirp(directory)
    return

pathhandlermodule.somethingExistsAtBase = (name) ->
    something = pathModule.resolve(pathhandlermodule.basePath, name)
    return await checkSomethingExists(something)

pathhandlermodule.directoryExistsAtBase = (dirName) ->
    dirPath = pathModule.resolve(pathhandlermodule.basePath, dirName)
    return await checkDirectoryExists(dirPath)

pathhandlermodule.doesExists = (name) ->
    return await checkSomethingExists(name)

pathhandlermodule.directoryExists = (dirName) ->
    return await checkDirectoryExists(dirName)
#endregion
#endregion

module.exports = pathhandlermodule