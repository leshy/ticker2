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

  if process.env.NODE_ENV is "production"
    console.log "PRODUCTION"
    env.logger.outputs.push new logger3.Influx do
      connection: { database: 'ticker2', host: 'localhost' }
      tagFields: { +module, +app, +currency, +market, +type }
  else
    console.log "DEV"

  tick = -> 
    p.props do
      # korbitOrderbookBTC: request.get('https://api.korbit.co.kr/v1/orderbook?category=bid').then -> JSON.parse(it)
      
      KORBIT:
        p.props do
          KRW_BTC: request.get('https://api.korbit.co.kr/v1/ticker').then -> Number JSON.parse(it).last
          KRW_ETH: request.get('https://api.korbit.co.kr/v1/ticker?currency_pair=eth_krw').then -> Number JSON.parse(it).last
#          KRW_LTC: request.get('https://api.korbit.co.kr/v1/ticker?currency_pair=ltc_krw').then -> Number JSON.parse(it).last
          
      BITSTAMP: request.get('https://www.bitstamp.net/api/v2/ticker/btceur/').then -> EUR_BTC: Number JSON.parse(it).last
      
      POLONIEX: request.get('https://poloniex.com/public?command=returnTicker').then ->
        vals = mapValues JSON.parse(it), -> Number it.last
        return do
          BTC_ETH: vals.BTC_ETH
          BTC_LTC: vals.BTC_LTC
      
      EXCHANGE: request.get('https://api.fixer.io/latest').then -> KRW_EUR: Number JSON.parse(it).rates.KRW
      
    .then (markets) ->
      markets.KORBIT <<< do
        BTC_ETH: markets.KORBIT.KRW_ETH / markets.KORBIT.KRW_BTC
#        BTC_LTC: markets.KORBIT.KRW_LTC / markets.KORBIT.KRW_BTC
        EUR_BTC: markets.KORBIT.KRW_BTC / markets.EXCHANGE.KRW_EUR

      each markets, (data, market) ->
        each data, (val, currency) -> 
          env.logger.log "#{market} #{currency} #{val}", {}, { market: market, currency: currency, value: val, type: 'exchange' }

      diffs = do
        KORBIT_BITSTAMP_BTC: (100 - (markets.BITSTAMP.EUR_BTC / markets.KORBIT.EUR_BTC) * 100)
        KORBIT_POLONTEX_ETH: (100 - (markets.POLONIEX.BTC_ETH / markets.KORBIT.BTC_ETH) * 100)
#        KORBIT_POLONTEX_LTC: (100 - (markets.POLONIEX.BTC_LTC / markets.KORBIT.BTC_LTC) * 100)

      each diffs, (val, currency) ->
        env.logger.log "DIFF_#{currency} #{val}", {}, { market: "DIFF_#{currency}", currency: 'EUR_BTC', type: 'diff', value: val }
            
  if process.env.NODE_ENV is "production" then setInterval tick, 60000
  tick()

