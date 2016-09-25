_ = require 'underscore'
React = require 'react'
moment = require 'moment-timezone'

Transfer = React.createClass

    render: ->
        <div className='transfer'>
            &rarr; {@props.to}
        </div>

Txid = ({txid}) ->
    render: ->
        if @props.type
            base_url = encodeURIComponent('localhost:3534/#/')
            <a className='txid' href="http://localhost:1188/pending/#{txid}?redirect=#{base_url}#{@props.type}/[t.contractAddress]" target="_newtab">{txid}</a>

        else
            <a className='txid' href="http://localhost:1188/pending/#{txid}" target="_newtab">{txid}</a>

stringToColor = (str) ->
    hash = 0;
    [0..str.length].map (i) ->
        hash = str.charCodeAt(i) + ((hash << 5) - hash)
    colour = '#'
    value = 0
    [0..2].map (i) ->
        value = (hash >> (i * 8)) && '0xFF';
    colour += ('00' + value.toString(16)).substr(-2)
    return colour

stringToColor = (str) ->
    return (parseInt(parseInt(str).toExponential().slice(2,-5), 10) & 0xFFFFFF).toString(16).toUpperCase()

addressToColor = (address) ->

    return '#9' + address.slice(-5)

ContractMixin =

    renderField: (f) ->
        <div className='field' key=f >
            <label>{f}</label>
            <div className='value'>{@state.contract?[f]}</div>
        </div>

    renderSubcontractField: (model, f) ->
        <div className='model-field' key=f >
            <h5>{f}</h5>
            <div className=''>{model[f]}</div>
        </div>

LogItem = React.createClass

    render: ->
        {l} = @props
        _color = stringToColor(l.address)
        _style = {color: '#' + '9' + _color.slice(-5)}
        console.log _color, _style
        <div className='log' key=l.address >
            {if l.kind then <div className="tag #{l.kind}">{l.kind}</div>}
            <div className='metadata'>
                <a href="http://etherscan.io/tx/#{l.event.transactionHash}" target="_newtab"><div className='timestamp'>{moment(l.event.block.timestamp*1000).format('HH:mm:ss')}</div></a>
                {if l.address then <a className='address' style={_style} title="#{l.address}" target="_newtab" href="http://etherscan.io/address/etherscan.io/address/#{l.address}"><div className='address'>{'<...' + l.address.slice(-10) + '> :'}</div></a>}
            </div>
            <div className='message'>{l.message}</div>
        </div>
            # <div className='before-message'><i className='fa fa-angle-right' /></div>

module.exports = {
    Transfer
    Txid
    ContractMixin
    LogItem
}