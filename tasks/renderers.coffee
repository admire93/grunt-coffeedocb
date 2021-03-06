###
Renderer for grunt

most of all, copy and paste of coffedoc/src/renderers.coffee
###

fs = require('fs')
path = require('path')
eco = require('eco')
traverse = require('traverse')
highlight = require('highlight').Highlight
marked = require('marked')
coffeedocsrc = __dirname + '/../node_modules/coffeedoc/src'
Renderer = require(coffeedocsrc + '/renderers')


class CoffeedocRenderer

    indexTemplate: null
    moduleTemplate: null
    indexFile: 'index'
    extension: ''


    constructor: (options) ->
        @writer = options.writer or fs.writeFile
        @options = {}
        for key, val of options
            if key of this
                this[key] = val
            else
                @options[key] = val

    renderIndex: (modules) =>
        eco.render(this.indexTemplate, {
            modules: modules.map(this.preprocess)
            options: this.options
        })

    renderModule: (module) =>
        eco.render(this.moduleTemplate, {
            module: this.preprocess(module)
            options: this.options
        })

    preprocess: (module) ->
        return module

    writeModules: (modules, outputdir) =>


class HtmlRenderer extends CoffeedocRenderer

    indexTemplate: fs.readFileSync(coffeedocsrc + '/../resources/html/index.eco', 'utf-8')
    moduleTemplate: fs.readFileSync(coffeedocsrc + '/../resources/html/module.eco', 'utf-8')
    baseCss: fs.readFileSync(coffeedocsrc + '/../resources/html/base.css', 'utf-8')
    extension: '.html'

    preprocess: (module) =>
        ###
        Convert markdown to html, adding syntax highlighting markup to any code
        blocks.

        Add the relative path to the resources directory to the documentation
        object so that generated pages know where to find css.
        ###
        marked.setOptions(highlight: (code, lang) -> highlight(code))
        module = traverse(module).map (value) ->
            if value and this.key == 'docstring'
                this.update(marked(value))

        basepath = path.relative(path.dirname(module.path), process.cwd())
        module.resourcepath = path.join(basepath, 'resources/')

        return module

    writeModules: (modules, outputdir) =>
        # Recreate source directory structure and write module documentation.
        for module in modules
            docpath = outputdir
            dirs = path.dirname(path.normalize(module.path)).split('/')
            for dir in dirs
                docpath = path.join(docpath, dir)
                if not fs.existsSync(docpath)
                    fs.mkdirSync(docpath, '755')
            outfile = path.join(outputdir, module.path + this.extension)
            @writer(outfile, this.renderModule(module))

        # Write css resources.
        resourcesdir = path.join(outputdir, 'resources')
        fs.mkdirSync resourcesdir, '755'
        @writer(path.join(resourcesdir, 'base.css'), this.baseCss)


class GithubWikiRenderer extends CoffeedocRenderer

    indexTemplate: fs.readFileSync(coffeedocsrc + '/../resources/github-wiki/index.eco', 'utf-8')
    moduleTemplate: fs.readFileSync(coffeedocsrc + '/../resources/github-wiki/module.eco', 'utf-8')
    indexFile: 'ModuleIndex'
    extension: '.md'

    _wikiize: (path) ->
        bits = path.split('/')
        bucket = []
        for b in bits
            if b
                bucket.push(b[0].toUpperCase() + b.substring(1))
        return bucket.join(':')

    _quoteMarkdown: (t) ->
        ###
        It's more than possible that a function name will have underscores...
        quote them.
        ###
        return t.replace(/([^\\])?_/g, "$1\\_")

    _params: (t) ->
        a = []
        for x in t
            if x?
                a.push(x)
            else
                a.push('{splat}')
        return a.join(', ')

    preprocess: (module) =>
        module.wikiname = this._wikiize(module.path.replace(/\.coffee$/, ''))
        module.quoteMarkdown = this._quoteMarkdown
        module.params = this._params
        return module

    writeModules: (modules, outputdir) =>
        for module in modules
            outfile = path.join(outputdir, module.wikiname + this.extension)
            @writer(outfile, this.renderModule(module))


class JSONRenderer extends CoffeedocRenderer

    extension: '.doc.json'
    indexFile: 'index'
    renderIndex: JSON.stringify
    renderModule: JSON.stringify


exports.html = HtmlRenderer
exports.gfm  = GithubWikiRenderer
exports.json = JSONRenderer
