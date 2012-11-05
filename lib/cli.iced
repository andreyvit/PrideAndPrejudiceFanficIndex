fs   = require 'fs'
Path = require 'path'

exports.run = (argv) ->
  options = require('dreamopt') [
    "Usage: jafanfic --scrape <site>"
    "Modes:"
    "  --scrape <site>     Scrape the given <site> (valid values: aha)"
    "Options:"
    "  -q, --quick         Try to speed up processing by reusing cached info like login cookies"
    "Generic options:"
  ], argv

  console.log "Options: %j", options

  try
    credentials = fs.readFileSync(Path.join(__dirname, '../config/credentials.json'), 'utf8')
  catch e
    process.stderr.write " ** Missing credentials config. Copy config/credentials.json.sample into config/credentials.json (and customize it).\n"
    return

  try
    credentials = JSON.parse(credentials)
  catch e
    process.stderr.write " ** Error parsing config/credentials.json: #{e.message}\n"
    return

  config =
    credentials: credentials
    interimDir: Path.join(__dirname, '../interim')
    quick: !!options.quick

  if options.scrape
    siteName = options.scrape
    SiteScraper = require "./scraper/#{siteName}"

    scraper = new SiteScraper(config, siteName)

    await scraper.run defer(err)
    if err
      process.stderr.write "Error: #{err.stack or err.message or err}\n"
    else
      process.stderr.write "Done.\n"
