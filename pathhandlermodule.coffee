pathhandlermodule = {name: "pathhandlermodule"}

#region modulesFromEnvironment
#region node_modules
fs          = require("fs-extra")
pathModule  = require("path")
os = require "os"
exec = require("child_process").exec
#endregion

#region localModules
utl = null
cfg = null
#endregion
#endregion

#region logPrintFunctions
##############################################################################
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["pathhandlermodule"]?  then console.log "[pathhandlermodule]: " + arg
    return
#endregion
##############################################################################
pathhandlermodule.initialize = () ->
    log "pathhandlermodule.initialize"
    utl = allModules.utilmodule
    cfg = allModules.configmodule
    await prepareUserConfigPath()
    return

#region internalProperties
homedir = os.homedir()

thingyName = ""
#endregion

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

#region exposed
#region exposedProperties
pathhandlermodule.homedir = homedir #directory
pathhandlermodule.userConfigPath = "" #file
pathhandlermodule.basePath = "" #directory
pathhandlermodule.thingyPath = "" #directory
pathhandlermodule.temporaryFilesPath = "" #directory
pathhandlermodule.recipesPath = ""
#endregion

#region exposedFunctions
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

# pathhandlermodule.ensureDirectoryExists = (dirName) ->

#region oldCode
pathhandlermodule.checkCreatability = (directoryName) ->
    directoryPath = pathModule.resolve(pathhandlermodule.basePath, directoryName)
    exists = await checkDirectoryExists(directoryPath)
    if exists
        throw "The directory at " + directoryPath + " already exists!"

pathhandlermodule.createInitializationBase = (name) ->
    thingyName = name
    pathhandlermodule.thingyPath = pathModule.resolve(pathhandlermodule.basePath, thingyName)
    pathhandlermodule.basePath = pathModule.resolve(pathhandlermodule.basePath, name + "-init")
    await fs.mkdirs(pathhandlermodule.basePath)

pathhandlermodule.cleanInitializationBase = () ->
    initializedThingyPath = pathModule.resolve(pathhandlermodule.basePath, thingyName)
    await fs.move(initializedThingyPath, pathhandlermodule.thingyPath)
    await fs.remove(pathhandlermodule.basePath)
    pathhandlermodule.basePath = pathModule.resolve(pathhandlermodule.basePath, "..")

pathhandlermodule.getBasePath = () ->
    return pathhandlermodule.basePath

pathhandlermodule.getGitPaths = (name) ->
    r = {}
    r.repoDir = pathModule.resolve(pathhandlermodule.basePath, name)
    r.gitDir = pathModule.resolve(r.repoDir, ".git")
    return r

pathhandlermodule.getLicenseSourcePaths = () ->
    r =  {}
    r.licensePath = pathModule.resolve(__dirname, "LICENSE")
    r.unlicensePath = pathModule.resolve(__dirname, "UNLICENSE")
    return r

pathhandlermodule.getLicenseDestinationPaths = (repoDir) ->
    r =  {}
    r.licensePath = pathModule.resolve(repoDir, "LICENSE")
    r.unlicensePath = pathModule.resolve(repoDir, "UNLICENSE")
    return r

pathhandlermodule.setThingyPath = (path) ->
    pathhandlermodule.thingyPath = path

pathhandlermodule.getToolsetPath = ()  ->
    return pathModule.resolve(pathhandlermodule.thingyPath, "toolset")

pathhandlermodule.getPreparationScriptPath = (scriptFileName) ->
    return pathModule.resolve(pathhandlermodule.thingyPath, "toolset", scriptFileName)
#endregion
#endregion
#endregion
module.exports = pathhandlermodule