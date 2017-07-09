_ = require 'underscore'
async = require 'async'
somata = require 'somata'
Web3 = require 'web3'
SolidityCoder = require("web3/lib/solidity/coder.js")
config = require '../config'

eve = require('eve-node')({eth_addresses: config.eth_addresses})
GenericEve = eve.buildGenericMethods {ThreadedChat: require './threaded-chat'}
{sendTransaction, deploy, getParameter, callFunction, compileContractData, decodeEvent, abis} = GenericEve

client = new somata.Client()

{CONTRACT_ADDRESS} = config

LoginService = client.remote.bind client, 'eth-login:contracts'
DataService = client.remote.bind client, 'eth-services:data'

usernames = []

# Start web3
web3 = new Web3()
web3.setProvider(new web3.providers.HttpProvider("http://#{config.eth_ip}:8545"))

attachBlock = (i, cb) ->
    web3.eth.getBlock i.blockHash, (err, block) ->
        i.block = block
        cb null, i

subscribeAllRooms = ->

    address = CONTRACT_ADDRESS
    web3.eth.getBlockNumber (err, block_no) ->
        contract_filter = web3.eth.filter({fromBlock:block_no, toBlock: 'latest', address})
        contract_filter.watch (err, result) ->
            attachBlock result, (err, result) ->
                result.decoded = decodeEvent 'ThreadedChat', result
                _data = attachUsername result

                if _data?
                    console.log result, _data
                    console.log "New event", result
                    console.log "Decoded to", _data
                    console.log "rooms:#{_data.decoded.room}:events"
                    service.publish "rooms:#{_data.decoded.room}:events", _data


            web3.eth.getTransactionReceipt result.transactionHash, (err, tx) ->
                DataService 'create', 'transactions', tx, (err, created) ->
                    console.log 'created transaction', created

subscribeAllRooms()

subscribeRoom = (room_slug, cb) ->
    console.log 'TODO: subscribe room_slug', room_slug
    cb null, room_slug

hydrateEvents = (events, cb) ->
    async.map events, attachBlock, (err, events) ->
        data = events.map (e) ->
            e.decoded = decodeEvent 'ThreadedChat', e
            return e
        data = data.map (_d) -> attachUsername _d
        cb err, data

findRoomEvents = (room, cb) ->
    # TODO: eventually search by decoded data
    DataService 'find', 'transactions', {to: CONTRACT_ADDRESS}, {}, {all: true}, (err, transactions) ->
        events = _.flatten transactions.map((t) -> t.logs)
        hydrateEvents events, (err, events) ->
            events = events.filter (e) -> e.decoded.room == room
            cb err, events

# # eth-login implementation
# # -----------------------------------------------------------------------------

attachUsername = (_data) ->
    if username = _.findWhere usernames, {address: _data.address}
        _data.username = username.username
    return _data

# LoginService 'findUsernames', config.login_store, (err, u) ->
#     usernames = u

# client.subscribe "eth-login:contracts", "contracts:#{config.login_store}:all_usernames", (data) ->
#     console.log 'A user logged in', data
#     {address, username} = data
#     if address? && username?
#         usernames = usernames.filter (u_a) -> u_a.address != address
#         usernames.push {address, username}
#         service.publish "all_usernames", {address, username}

service = new somata.Service 'eth-chatter:events', {
    subscribeRoom
    findRoomEvents
}