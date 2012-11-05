debug = require('debug')('jafanfic:scraper:aha')

module.exports =
class AhaScraper extends require('./base')
  initialize: ->
    @baseUrl = "http://meryton.com/aha/index.php"
