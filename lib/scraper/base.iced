debug = require('debug')('jafanfic:scraper:base')

Browser = require 'zombie'
fs      = require 'fs'
Path    = require 'path'
Url     = require 'url'
numpad  = require 'numpad'
_       = require 'underscore'
moment  = require 'moment'

{ Apricot } = require 'apricot'

$A = _.toArray


siblingsAfter = (el, condition=(-> yes)) ->
  while (el = el.nextSibling)? and condition(el) when el.nodeType == 1
    el


module.exports =
class Scraper

  constructor: (@config, @siteName) ->
    @credentials = @config.credentials[@siteName]
    @browser = new Browser({ runScripts: no, loadCSS: no })
    @initialize?()


  saveData: (fileName, data) ->
    fileName = "#{@siteName}_#{fileName}"
    fs.writeFileSync(Path.join(@config.interimDir, fileName), data)
    debug "Saved #{fileName}"

  loadData: (fileName) ->
    fileName = "#{@siteName}_#{fileName}"
    try
      fs.readFileSync(Path.join(@config.interimDir, fileName), 'utf8')
    catch e
      null


  loadWithCaching: (fileName, url, callback) ->
    if @config.quick and (html = @loadData(fileName))
      debug "Using cached #{fileName}"
      callback(null, html)
    else
      debug "Downloading #{Path.basename(fileName)} from #{url}..."
      await @browser.visit(url, defer())
      await @browser.wait defer()

      html = @browser.html()
      @saveData fileName, html

      if @browser.success
        callback(null, html)
      else
        callback("Failed to load #{Path.basename(fileName)}")

  loadAndParse: (fileName, url, callback) ->
    await @loadWithCaching fileName, url, defer(err, html)
    return callback(err) if err

    debug "Parsing #{fileName}..."
    await Apricot.parse html, defer(err, doc)
    return callback(err) if err

    callback(null, doc)


  prepare: (callback) ->
    if @config.quick and (savedCookies = @loadData("cookies.txt"))
      @browser.loadCookies(savedCookies)
      debug "Using cached cookies: #{JSON.stringify(_.pick(@browser.cookies, 'key', 'value'), null, 2)}"
      callback(null)
    else
      @login callback


  login: (callback) ->
    debug "Logging in using credentials: #{JSON.stringify(@credentials, null, 2)}"

    debug "Loading index page..."
    await @browser.visit("#{@baseUrl}?showforum=5", defer())
    @saveData 'login.html', @browser.html()
    return callback("Failed to load the site index page") unless @browser.success

    debug "Filling in login form..."
    @browser
      .fill("ips_username", @credentials.user)
      .fill("ips_password", @credentials.password)

    await @browser.pressButton "Sign In", defer()
    @saveData 'after_login.html', @browser.html()
    unless @browser.success
      @browser.dump()
      console.log "Response: " + @browser.lastResponse
      return callback("Failed to submit the login page: statusCode = #{@browser.statusCode}")

    debug "Obtained cookies: #{JSON.stringify(_.pick(@browser.cookies, 'key', 'value'), null, 2)}"
    debug "Cookies = %j", @browser.cookies
    @saveData "cookies.txt", @browser.saveCookies()

    callback(null)


  loadIndex: (callback) ->
    await @loadAndParse 'index.html', "#{@baseUrl}?showforum=5", defer(err, doc)
    return callback(err) if err

    topicListTable = doc.document.querySelector('.topic_list')
    if !topicListTable then return callback(new Error("Cannot find .topic_list table"))

    topicRows = $A topicListTable.querySelectorAll('tr[itemtype="http://schema.org/Article"]')
    console.log "topicRows.length = %d", topicRows
    if topicRows.length is 0 then return callback(new Error("Cannot find topic rows"))

    # topicsHeaderRow = _.find doc.find('tr.subhead.altbar').matches, (tr) => tr.textContent.trim().match /Forum Topics/
    # if !topicsHeaderRow then return callback(new Error("Cannot find Forum Topics row"))

    # topicRows = siblingsAfter(topicsHeaderRow).slice(1)

    topics = []
    for topicRow in topicRows
      { topic, message } = @processTopicRow(topicRow)

      unless topic
        console.log "Skipping row: %s", message #, topicRow.textContent.trim().substr(0, 100).replace(/\s{2,}/g, ' ')

      if topic
        debug "Found topic %s", JSON.stringify(topic, null, 2)
        topics.push topic

    callback(null, topics)

  processTopicRow: (topicRow) ->
    unless topicTitleLink = topicRow.querySelector('td.col_f_content a.topic_title')
      return message: "cannot find topic title"

    unless topicTitle = topicTitleLink.textContent.trim()
      return message: "empty topic title"

    unless topicURL = topicTitleLink.href?.trim()
      return message: "cannot find topic URL"

    unless topicId = topicRow.id?.replace(/^trow_/, '')
      return message: "cannot find topic ID"

    if isPinned = $A(topicRow.querySelectorAll('span')).some((span) -> span.textContent.trim().toLowerCase() == 'pinned')
      return message: "skipping pinned topic '#{topicTitle}'"

    posts = null
    for meta in $A(topicRow.querySelectorAll('meta[itemprop=interactionCount]'))
      if M = meta.content?.match(/^UserComments:(\d+)$/)
        posts = 1 + parseInt(M[1], 10)

    if viewsText = topicRow.querySelector('.views')?.textContent
      views = parseInt(viewsText, 10)
    else
      views = null

    # date = dateOrig = dateEl.textContent.trim()
    # date = date.replace /^Today,/, -> moment.utc().format('MMM DD YYYY')
    # date = date.replace /^Yesterday,/, -> moment.utc().subtract('days', 1).format('MMM DD YYYY')

    # date = moment.utc(date, 'MMM DD YYYY hh:mm a')

    topic =
      id:    topicId
      title: topicTitle
      url:   topicURL
      posts: posts
      views: views
      # author: authorLink.textContent.trim()
      # authorUrl: authorLink.getAttribute('href').trim()
      # lastUpdate: date.unix()
      # lastUpdateFmt: date.format('YYYY-MM-DD HH:mm:ss')
      # lastUpdateOrig: dateOrig
    return { topic }


  loadTopicPage: (topic, page, callback) ->
    url = "#{@baseUrl}?showtopic=#{topic.id}"
    if page > 0
      url = "#{url}&st=#{page}"

    await @loadAndParse "topic_#{topic.id}_p#{numpad page, 4}.html", url, defer(err, doc)
    return callback(err) if err

    if page is 0
      if topicHeader = doc.find('h2.maintitle').matches[0]
        if topicCategoriesSpan = topicHeader.getElementsByClassName('main_topic_desc').item(0)
          topic.tags = topicCategoriesSpan.textContent.trim().split(/\s*,\s*/)
          topicCategoriesSpan.parentNode.removeChild(topicCategoriesSpan)
        topic.title = topicHeader.textContent.trim()

    partDivs = doc.find('div.post_block').matches
    for partDiv in partDivs
      if postDateOrig = partDiv.getElementsByClassName('posted_info').item(0)?.getElementsByClassName('published').item(0)?.getAttribute('title') or ''
        postDate = moment.utc(postDateOrig)

      postBody = partDiv.getElementsByClassName('post').item(0)?.innerHTML.trim()

      topic.parts.push {
        date: postDate.unix()
        dateFmt: postDate.format('YYYY-MM-DD HH:mm:ss')
        dateOrig: postDateOrig
        body: postBody
      }

    nextPage = null
    if nextPageLink = doc.find('.topic_controls .pagination .next a').matches[0]
      nextPageUrl = nextPageLink.getAttribute('href').trim()
      nextPageUrlComponents = Url.parse(nextPageUrl, yes)
      if s = nextPageUrlComponents.query.st
        nextPage = parseInt(s, 10)
      debug "nextPageUrl = %j, nextPageUrlComponents = %j, nextPage = %j", nextPageUrl, nextPageUrlComponents, nextPage

    callback(null, nextPage)


  loadTopic: (topicId, callback) ->
    topic =
      id: topicId
      title: ''
      tags: []
      parts: []

    page = 0
    while page?
      debug "Topic #{topicId}, page #{page}"
      await @loadTopicPage topic, page, defer(err, page)
      return callback(err) if err

    fullHtml = (part.body for part in topic.parts).join("\n<hr>\n")
    @saveData "topic_#{topic.id}_body.html", fullHtml

    callback(null, topic)


  run: (callback) ->
    await @prepare defer(err)
    return callback(err) if err

    await @loadIndex defer(err, topics)
    return callback(err) if err

    for topic, index in topics.slice(0, 10)
      debug "Loading topic #{index+1}: #{topic.title} by #{topic.author}"
      await @loadTopic topic.id, defer(err, topicData)
      return callback(err) if err

      _.extend topicData, topic

    callback(null)
