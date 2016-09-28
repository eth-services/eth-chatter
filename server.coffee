somata = require 'somata'
polar = require 'somata-socketio'
h = require 'highlight.js'
fs = require 'fs'

Redis = require 'redis'
redis = Redis.createClient null, null

config = require './config'

{CONTRACT_ADDRESS} = config

client = new somata.Client()
ContractsService = client.bindRemote 'ethereum:contracts'
EventsService = client.bindRemote 'eth-chatter:events'

localsMiddleware = (req, res, next) ->
    Object.keys(config._locals).map (_l) ->
        res.locals[_l] = config._locals[_l]
    next()

highlightMiddleware = (req, res, next) ->
    res.locals.highlight = (filename) ->
        [filename, ext] = filename.split('.')
        source = fs.readFileSync "static/code/#{filename}.#{ext}"
        highlighted = h.highlight ext, source.toString()
        '<pre>\n' + highlighted.value.trim() + '</pre>'
    next()

app = polar config.app, middleware: [highlightMiddleware]

app.get '/', localsMiddleware, (req, res) ->
    res.render 'home'

['info','howto'].map (slug) ->
    app.get "/#{slug}", localsMiddleware, (req, res) ->
        res.render slug

app.get '/c/:chat_slug.json', (req, res) ->
    # TODO: get events filtered by chat_slug
    EventsService 'findRoomEvents', req.params.chat_slug, (err, events) ->

        res.json events

app.get '/c/:chat_slug', localsMiddleware, (req, res) ->
    {chat_slug} = req.params
    res.render 'chat', {chat_slug}

app.start()
