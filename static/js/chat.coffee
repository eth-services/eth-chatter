React = require 'react'
ReactDOM = require 'react-dom'
moment = require 'moment'

{Txid, ContractMixin, LogItem} = require './common'
KefirCollection = require 'kefir-collection'
fetch$ = require 'kefir-fetch'

somata = require './somata-stream'

Dispatcher =
    getRoomLogs: (slug) ->
        fetch$ 'get', "/c/#{slug}.json"
    pending_transactions$: KefirCollection([], id_key: 'hash')
    contract_logs$: KefirCollection([], id_key: 'id_hash')


Room = React.createClass
    mixins: [ContractMixin]

    getInitialState: ->
        logs: []
        loading: true
        transactions: []
        block_number: null

    componentDidMount: ->
        @logs$ = Dispatcher.getRoomLogs(window.chat_slug)
        @logs$.onValue @foundLogs
        @transactions$ = Dispatcher.pending_transactions$
        @transactions$.onValue @setTransactions
        @logs$ = Dispatcher.contract_logs$
        @logs$.onValue @handleLogs

    componentWillUnmount: ->
        @contract$.offValue @foundContract
        @transactions$.offValue @setTransactions
        @logs$.offValue @handleNewLog

    setTransactions: (transactions) ->
        @setState {transactions}

    foundLogs: (logs) ->
        logs.map (l) -> l.id_hash = l.event.blockNumber + '-' + l.logIndex
        @setState loading: false
        Dispatcher.contract_logs$.setItems logs

    handleLogs: (logs) ->
        @setState {logs}, =>
            @fixScroll()

    render: ->
        console.log @state
        <div className='log-insert'>
            <div>
                {@renderActivity()}
                <a className='sender' href='/howto'>Send a message</a>
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

somata.subscribe('eth-chatter:events', "rooms:#{window.chat_slug}:events").onValue (data) ->
    data.id_hash = data.event.blockNumber + '-' + (data.event.logIndex + 1)
    if !data.event.logIndex?
        console.log 'Its broken:', data.event.blockNumber + '-' + (data.event.logIndex + 1)
    Dispatcher.contract_logs$.updateItem data.id_hash, data

somata.subscribe('eth-chatter:events', "rooms:#{window.chat_slug}:all_events").onValue (data) ->
    data = data.map (d) ->
        d.id_hash = d.event.blockNumber + '-' + (d.event.logIndex + 1)
        return d
    Dispatcher.contract_logs$.setItems data

somata.subscribe('ethereum:contracts', "all_blocks").onValue (data) ->
    text = document.createTextNode("Block ##{data.number}... ")
    document.getElementById("block_counter").appendChild(text)

ReactDOM.render(<Room />, document.getElementById('insert'))

