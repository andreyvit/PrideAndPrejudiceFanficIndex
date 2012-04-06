fs   = require 'fs'
util = require 'util'

require 'sugar'

{ Apricot } = require 'apricot'

html = fs.readFileSync('results.html', 'utf8')

COLOR_MAP =
  'a0ffa0': 'normal'
  'bbeeff': 'blue'   # ???
  'ffffa0': 'steamy'
  'ffd0d0': 'extra-steamy'

rowIndex = 0
stories = []

html.replace /// <tr\s+class="lsthrl"><td\s+colspan="19"></td></tr>\s*([^\u0001]*?)<tr\s+class="lsthrl"><td\s+colspan="19"></td></tr> ///g, (match, row) ->
  # util.debug "row #{++rowIndex}"
  Apricot.parse row, (err, doc) ->
    throw err if err

    categories = []
    doc.find('ul').each (ul) ->
      items = []
      # util.debug util.inspect ul.elements
      for li in ul.getElementsByTagName('li')
        items.push(li.textContent.trim())
      categories.push items
    .remove()

    author = ''
    doc.find('td .ftny.ital').each (item) ->
      parent = item.parentNode
      parent.removeChild(item)
      author = parent.textContent.trim()
      parent.parentNode.removeChild(parent)

    tags = ''

    doc.find('td').each (td) ->
      if td.innerHTML.match(///^ \s* <i> [^\u0001]* </i> \s* $///)
        tags = (tag.trim() for tag in td.textContent.split(/\s{6}/))
        td.parentNode.removeChild(td)
        # util.debug td.innerHTML

    # process.exit 0

    parseSource = (td) ->
      name = td.textContent.trim()
      return null unless name

      a = td.getElementsByTagName('a')[0]
      href = ''
      color = ''
      login = no
      if a
        href = (a.getAttribute('href') || '').trim()
      return null unless href

      style = td.getAttribute('style') || ''
      if m = style.match /background-color:\s*#([0-9a-f]{6})/
        color = m[1]
        color = COLOR_MAP[color] || color
      if m = style.match /border:\s*2px\s+solid\s+#000/
        login = yes

      return { name, href, color, login }


    tds = doc.find('td').matches
    story =
      complete: tds[0].getElementsByTagName('img').length == 0
      name:    tds[2].textContent.trim()
      era:     tds[3].textContent.trim()
      date:    tds[4].textContent.trim()
      sources: (parseSource(tds[i]) for i in [5..13] by 2).compact()
      novel:   tds[15].textContent.trim()
      words:   tds[16].textContent.trim()
      categories: categories
      tags: tags
      author: author

    others = (td.textContent.trim() for td in tds.slice(17))
    others = (o for o in others when o.length > 0)

    story.description = others

    return if story.novel isnt 'P&P'
    return if story.sources.length == 0
    return unless story.complete

    stories.push story
    util.debug "#{stories.length}) #{story.name}"
    util.debug JSON.stringify(story, null, 2)

util.debug 'Saving...'
fs.writeFileSync 'stories.json', JSON.stringify(stories, null, 2)

#   if m = row.match /// <tr><td><img src="statcur.gif" width="8px" height="8px" /></td><td></td>\s*<td[^>]*>(.*?)</td> ///
#     name = m[1]
#     util.debug "Name: #{name}"
#   else
#     util.debug "Unparsed: #{row}"

# [ 'nodeValue',
#   'getElementsByClassName',
#   'tagName',
#   'id',
#   'nodeType',
#   'sourceIndex',
#   'attributes',
#   'outerHTML',
#   'innerHTML',
#   'name',
#   'createCaption',
#   'getAttribute',
#   'setAttribute',
#   'focus',
#   'blur',
#   'removeAttribute',
#   'elements',
#   'getAttributeNode',
#   'setAttributeNode',
#   'nodeName',
#   'removeAttributeNode',
#   'scrollTop',
#   'scrollLeft',
#   'getElementsByTagName',
#   'href',
#   'height',
#   'width',
#   'src',
#   'lang',
#   'className',
#   'disabled',
#   'selected',
#   'checked',
#   'type',
#   'options',
#   'selectedIndex',
#   'text',
#   'value',
#   'textContent' ]


 # find: [Function],
 #  live: [Function],
 #  each: [Function],
 #  remove: [Function],
 #  inner: [Function],
 #  outer: [Function],
 #  top: [Function],
 #  bottom: [Function],
 #  before: [Function],
 #  after: [Function],
 #  html: [Function],
 #  hasClass: [Function],
 #  removeClass: [Function],
 #  addClass: [Function],
 #  _wrapHelper: [Function],
 #  _clean: [Function],
 #  _wrap: [Function],
 #  on: [Function] }
