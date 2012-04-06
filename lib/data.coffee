fs   = require 'fs'
Path = require 'path'


String::permalink = -> this.replace(/'/g, '').replace(/\W+/g, '-').toLowerCase()


class Repository
  constructor: () ->
    @stories = []
    @storiesByPermalink = {}
    @categories = {}
    @categoriesByPermalink = {}

  lookupCategory: (name) ->
    @categories[name] ||= do =>
      category = new Category(name)
      @categoriesByPermalink[category.permalink] = category
      category

  add: (story) ->
    @stories.push(story)
    @storiesByPermalink[story.permalink] = story
    story.categories = (@lookupCategory(name) for name in story.categoryNames)
    for category in story.categories
      category.stories.push(story)
    return

  finalize: ->
    @allCategories = (category for own _, category of @categories)
    for own _, category of @allCategories
      category.finalize()


class Category
  constructor: (@name) ->
    @stories = []
    @permalink = @name.permalink()

  finalize: ->


class Story
  constructor: (@json) ->
    @name       = @json.name
    @era        = @json.era
    @isComplete = @json.complete
    @date       = @json.date
    @sources    = @json.sources
    @words      = @json.words
    @wordsNum   = if @words then parseInt(@words.replace(/\D/g, ''), 10) else 0
    @description = @json.description || []

    @permalink = @name.permalink()

    @categoryNames = (@json.categories || []).flatten()

    if @json.sources.map('color').indexOf('extra-steamy') >= 0
      @categoryNames.push 'Steamy'
      @categoryNames.push 'Extra Steamy'
    else if @json.sources.map('color').indexOf('steamy') >= 0
      @categoryNames.push 'Steamy'

    if @era is 'R'
      @categoryNames.push 'Regency'
    else if @era is 'M'
      @categoryNames.push 'Modern'
    else if @era is 'O'
      @categoryNames.push 'Other Past'
    else if @era is 'F'
      @categoryNames.push 'Future'



module.exports = do ->
  repository = new Repository()

  stories = (new Story(json) for json in JSON.parse(fs.readFileSync(Path.join(__dirname, '../stories.json'))))
  for story in stories
    repository.add story

  repository.finalize()

  repository
