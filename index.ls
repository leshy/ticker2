require! {
  ribcage: { init }
  leshdash: { map, mapKeys, round, filter, reduce, mapValues, each }
  'request-promise': request
  bluebird: p
  'logger3/server': logger3
}


env = {} 

init env, (err,env) ->
  env.logger.addTags pid: process.pid, app: "ticker"

  env.logger.outputs.push new logger3.Influx do
    connection: { database: 'ticker2', host: 'localhost' }
    tagFields: { +module, +app, +metric }

  tick = -> 
    p.props do
      # korbitOrderbookBTC: request.get('https://api.korbit.co.kr/v1/orderbook?category=bid').then -> JSON.parse(it)
      
      KORBIT:
        p.props do
          KRW_BTC: request.get('https://api.korbit.co.kr/v1/ticker').then -> Number JSON.parse(it).last
          KRW_ETH: request.get('https://api.korbit.co.kr/v1/ticker?currency_pair=eth_krw').then -> Number JSON.parse(it).last
          
      BITSTAMP: request.get('https://www.bitstamp.net/api/v2/ticker/btceur/').then -> EUR_BTC: Number JSON.parse(it).last
      
      POLONIEX: request.get('https://poloniex.com/public?command=returnTicker').then ->
        vals = mapValues JSON.parse(it), -> Number it.last

        return do
          BTC_ETH: vals.BTC_ETH
      
      EXCHANGE: request.get('https://api.fixer.io/latest').then -> KRW_EUR: Number JSON.parse(it).rates.KRW
      
    .then (markets) ->
      markets.KORBIT <<< do
        BTC_ETH: markets.KORBIT.KRW_ETH / markets.KORBIT.KRW_BTC
        EUR_BTC: markets.KORBIT.KRW_BTC / markets.EXCHANGE.KRW_EUR
        ETH_BTC: markets.KORBIT.KRW_BTC / markets.EXCHANGE.KRW_EUR


      ret = {}
      each markets, (data, market) ->
        each data, (val, currency) -> ret <<< "#{market}_#{currency}": val

      console.log ret
                  
#      env.logger.log "exchange #{data.exchangeKRW} KRW for 1 EUR" { exchange: data.exchangeKRW }, metric: 'exchange'
      
  setInterval tick, 60000
  tick()

