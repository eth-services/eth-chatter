React = require 'react'
ReactDOM = require 'react-dom'
moment = require 'moment'

{Txid, ContractMixin, LogItem} = require './common'
KefirCollection = require 'kefir-collection'
KefirBus = require 'kefir-bus'
fetch$ = require 'kefir-fetch'

somata = require 'somata-socketio-client'
eve = require 'eve-js'
threaded_chat_abi = require './threaded-chat-abi'

chat_api = eve.buildAPIWithABI threaded_chat_abi

Dispatcher =
    getRoomLogs: (slug) ->
        fetch$ 'get', "/c/#{slug}.json"
    pending_transactions$: KefirCollection([], id_key: 'hash')
    contract_logs$: KefirCollection([], id_key: 'id_hash')
    new_username$: KefirBus()


Room = React.createClass
    mixins: [ContractMixin]

    getInitialState: ->
        logs: []
        loading: true
        transactions: []
        block_number: null
        message: ''

    componentDidMount: ->
        @logs$ = Dispatcher.getRoomLogs(window.chat_slug)
        @logs$.onValue @foundLogs
        @transactions$ = Dispatcher.pending_transactions$
        @transactions$.onValue @setTransactions
        @logs$ = Dispatcher.contract_logs$
        @logs$.onValue @handleLogs
        @usernames$ = Dispatcher.new_username$
        @usernames$.onValue @handleNewUsername

    componentWillUnmount: ->
        @contract$.offValue @foundContract
        @transactions$.offValue @setTransactions
        @logs$.offValue @handleNewLog
        @usernames$.offValue @handleNewUsername

    setTransactions: (transactions) ->
        @setState {transactions}

    foundLogs: (logs) ->
        console.log logs
        logs.map (l) -> l.id_hash = l.blockNumber + '-' + l.logIndex
        @setState loading: false
        Dispatcher.contract_logs$.setItems logs

    handleLogs: (logs) ->
        console.log logs, 'New log'
        @setState {logs}, =>
            @fixScroll()

    changeValue: (key, e) ->
        new_state = {}
        new_state[key] = e.target.value
        @setState new_state

    onKeyPress: (e) ->
        if e.key == 'Enter' and !e.shiftKey
            e.preventDefault()
            @onSubmit(e)

    onSubmit: (e) ->
        e.preventDefault()
        if !@state.message?.trim().length
            return
        {message} = @state
        to = CONTRACT_ADDRESS
        fn = 'sendChat'
        room = window.location.pathname.split('/')[2]
        options = {gas: 30000}
        chat_api.sendChat to, room, message, options, @handleWeb3Response
        # eve.execWithABI threaded_chat_abi, to, fn, room, message, options, @handleWeb3Response

    handleWeb3Response: (resp) ->
        console.log resp

    handleNewUsername: ({username, address}) ->
        logs = @state.logs
        new_logs = logs.map (l) ->
            if l.address == address
                l.username = username
            return l
        @setState logs: new_logs

    render: ->
        <div className='log-insert'>
            <div>
                {@renderActivity()}
                {if window.web3?
                    <input
                        value=@state.message
                        placeholder='Send a message'
                        onKeyPress=@onKeyPress
                        onChange={@changeValue.bind(null, 'message')}
                    />
                else
                    <a className='sender' href='/howto'>Send a message</a>
                }
            </div>
            <div className='col half'>
                <h3>Pending Transactions</h3>
                {@state.transactions.map (t, i) ->
                    <div><Txid txid={t.hash} key=i /></div>
                }
            </div>
        </div>

    renderActivity: ->
        <div className='logs' id='logs'>
            {if @state.loading
                <div className='loading'>loading...</div>
            else
                [<div className='log'>
                    eth-chatter.io <a href='http://github.com/eth-services/eth-chatter'>v0.0.1</a>
                </div>
                ,
                <div className='log'>
                    furnished by <a href='http://eth-services.io'>eth-services.io</a>
                </div>]
            }
            {@state.logs.map @renderLog}
        </div>

    renderLog: (l, i) ->
        <LogItem l=l key=i />

    fixScroll: ->
        $logs = document.getElementById('logs')
        $logs?.scrollTop = $logs?.scrollHeight

module.exports = Room
console.log "rooms:#{window.chat_slug}:events"
somata.subscribe 'eth-chatter:events', "rooms:#{window.chat_slug}:events", (data) ->
    console.log 'test jones ii', data
    data.id_hash = data.blockNumber + '-' + (data.logIndex + 1)
    if !data.logIndex?
        console.log 'Its broken:', data.blockNumber + '-' + (data.logIndex + 1)
    Dispatcher.contract_logs$.updateItem data.id_hash, data

somata.subscribe 'eth-chatter:events', "rooms:#{window.chat_slug}:all_events", (data) ->
    console.log 'test jones', data
    data = data.map (d) ->
        d.id_hash = d.blockNumber + '-' + (d.logIndex + 1)
        return d
    Dispatcher.contract_logs$.setItems data

somata.subscribe 'ethereum:contracts', "all_blocks", (data) ->
    text = document.createTextNode("Block ##{data.number}... ")
    document.getElementById("block_counter").appendChild(text)

somata.subscribe 'eth-chatter:events', "all_usernames", (data) ->
    console.log '[eth-login:events -- all_usernames -- BAD MAN', data
    # SOmething like this
    # Dispatcher.all_usernames$.updateItem data.address, data
    Dispatcher.new_username$.emit data

ReactDOM.render(<Room />, document.getElementById('insert'))

