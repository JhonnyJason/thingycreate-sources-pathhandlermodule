pathhandlermodule = {name: "pathhandlermodule"}
############################################################
#region logPrintFunctions
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["pathhandlermodule"]?  then console.log "[pathhandlermodule]: " + arg
    return
olog = (o) -> log "\n" + ostr(o)
ostr = (o) -> JSON.stringify(o, null, 4)
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
#region localModules
utl = null
cfg = null
#endregion
#endregion

############################################################
#region internalProperties
homedir = os.homedir()
thingyName = ""
try specifics = require "./pathhandlerspecifics" catch err
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
#region exposed
#region exposedProperties
pathhandlermodule.keysDirectory = ""
pathhandlermodule.configPath = ""

pathhandlermodule.homedir = homedir #directory
pathhandlermodule.userConfigPath = "" #file
pathhandlermodule.basePath = "" #directory
pathhandlermodule.thingyPath = "" #directory
pathhandlermodule.temporaryFilesPath = "" #directory
pathhandlermodule.recipesPath = ""
#endregion

#region exposedFunctions
pathhandlermodule.setKeysDirectory = (keysDir) ->
    if keysDir
        if pathModule.isAbsolute(keysDir)
            pathhandlermodule.keysDirectory = keysDir
        else
            pathhandlermodule.keysDirectory = pathModule.resolve(process.cwd(), keysDir)
    else
        throw "Trying to set undefined or empty directory for the keys."

    exists = await checkDirectoryExists(pathhandlermodule.keysDirectory)
    if !exists
        throw new Error("Provided directory " + keysDir + " does not exist!")

pathhandlermodule.setConfigFilePath = (configPath) ->
    if configPath
        if pathModule.isAbsolute(configPath)
            pathhandlermodule.configPath = configPath
        else
            pathhandlermodule.configPath = pathModule.resolve(process.cwd(), configPath)
    else
        throw "Trying to set undefined or empty directory for the keys."

pathhandlermodule.getConfigRequirePath = -> pathhandlermodule.configPath

pathhandlermodule.getPrivKeyPath = (repo) ->
    return pathModule.resolve(pathhandlermodule.keysDirectory, repo)

pathhandlermodule.getPubKeyPath = (repo) ->
    return pathModule.resolve(pathhandlermodule.keysDirectory, repo + ".pub")

pathhandlermodule.resolve = (base, other) ->
    log "pathhandlermodule.resolve"
    return pathModule.resolve(base, other)

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

#endregion
#endregion
module.exports = pathhandlermodule