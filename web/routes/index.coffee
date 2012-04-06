
repository = require '../lib/data'


class View
  @parse: (path) ->
    if path is '/'
      new View([])
    else
      new View(path.split('/').slice(2))

  constructor: (@permalinks) ->

  toURL: ->
    if @permalinks.length > 0
      "/t/" + @permalinks.join('/')
    else
      "/"

  toTitle: ->
    @breadcrumbs.slice(0).reverse().map('title').join(" — ")

  subview: (permalink) ->
    new View(@permalinks.concat([permalink]))

  resolve: ->
    storyPermalinks = (story.permalink for story in repository.stories)
    @activeCategories = []
    for permalink in @permalinks
      category = repository.categoriesByPermalink[permalink]
      unless category
        throw new Error("Category with permalink '#{permalink}' does not exist")
      @activeCategories.push(category)
      storyPermalinks = storyPermalinks.intersect(story.permalink for story in category.stories)

    @breadcrumbs = []
    @breadcrumbs.push { title: 'Pride & Prejudice', url: '/' }
    for category, index in @activeCategories
      @breadcrumbs.push { title: category.name, url: new View(@permalinks.slice(0, index + 1)).toURL() }
    @breadcrumbs[@breadcrumbs.length - 1].active = yes

    @stories = (repository.storiesByPermalink[permalink] for permalink in storyPermalinks).sortBy('wordsNum')

    @categories = (story.categories for story in @stories).flatten().unique((c) -> c.name).filter((category) => @permalinks.indexOf(category.permalink) < 0)

    for category in repository.allCategories
      category.storyPermalinks = storyPermalinks.intersect(story.permalink for story in category.stories)
      category.storyCount = category.storyPermalinks.length
      category.overallStoryCount = category.stories.length
      category.isUseless = (category.storyCount == @stories.length)
      category.view = @subview(category.permalink)
      category.url = category.view.toURL()
      category.isActive = @permalinks.indexOf(category.permalink) >= 0
      category.topLevelUrl = new View([category.permalink]).toURL()
      category.subviewUrl = @subview(category.permalink).toURL()

    maxStoryCount = @categories.map('storyCount').max()
    @categories = @categories.filter((c) => !c.isUseless && (c.storyCount > Math.max(1, maxStoryCount / 20)))

    for story in @stories
      story.url = "/s/#{story.permalink}"

    @categories = @categories.sortBy((c) -> -c.storyCount)

    this


exports.index = (req, res) ->
  view = View.parse(req.path).resolve()

  res.render 'index',
    title: view.toTitle()
    header: view.breadcrumbs[view.breadcrumbs.length - 1].title
    view: view
