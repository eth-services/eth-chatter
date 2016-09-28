_ = require 'underscore'
async = require 'async'
somata = require 'somata'
Web3 = require 'web3'
SolidityCoder = require("web3/lib/solidity/coder.js")

config = require '../config'

client = new somata.Client()

{CONTRACT_ADDRESS} = config

LoginService = client.bindRemote 'eth-login:events'
usernames = []

attachUsername = (_data) ->
    if username = _.findWhere usernames, {address: _data.address}
        _data.username = username.username
    return _data

# Start web3
web3 = new Web3()
web3.setProvider(new web3.providers.HttpProvider("http://#{config.eth_ip}:8545"))

processEvent = (e) ->
    # TODO: switch to using "indexed" events for room
    _data = SolidityCoder.decodeParams(["address", "string", "string"], e.data.replace("0x",""))
    # _data_2 = SolidityCoder.decodeParams(["string"], e.topics[1].replace("0x",""))
    [address, room, message] = _data
    return {address, room, message, event: e}

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

                _data = processEvent result
                async.map result, attachBlock, (err, result) ->
                    _data = attachUsername _data

                    if _data?
                        console.log result, _data
                        console.log "New event", result
                        console.log "Decoded to", _data
                        service.publish "rooms:#{_data.room}:events", _data

subscribeAllRooms()

subscribeRoom = (room_slug, cb) ->
    console.log 'TODO: subscribe room_slug', room_slug
    cb null, room_slug

findRoomEvents = (room, cb) ->
    console.log 'finding room events'
    filter = web3.eth.filter({fromBlock: 0, toBlock: 'latest', address: CONTRACT_ADDRESS})

    filter.get (err, result) ->
        async.map result, attachBlock, (err, result) ->
            data = result.map (r) ->
                processEvent r

            data = data.filter (d) -> d.room == room
            data = data.map (_d) -> attachUsername _d

            cb err, data

checkContractEvents = (address, cb) ->
    return cb null, true
    filter = web3.eth.filter({fromBlock:0, toBlock: 'latest', address})
    filter.get (err, result) ->
        return console.log err, address if err?

        async.map result, attachBlock, (err, result) ->
            data = result.map (r) ->
                processEvent r
            data = _.compact data
            console.log data.map (d) -> d.event.blockNumber + '-' + d.event.logIndex

LoginService 'findUsernames', config._locals.login_address, (err, u) ->
    console.log u
    usernames = u

client.on "eth-login:events", "contracts:#{config._locals.login_address}:all_usernames", (data) ->
    console.log 'yes?', data
    {address, username} = data
    if address? && username?
        usernames = usernames.filter (u_a) -> u_a.address != address
        usernames.push {address, username}
        service.publish "all_usernames", {address, username}

service = new somata.Service 'eth-chatter:events', {
    checkContractEvents
    subscribeRoom
    findRoomEvents
}