Browser = require 'zombie'
fs      = require 'fs'

browser = new Browser()

await browser.visit("http://www.jaffindex.com/", defer())
process.exit(1) unless browser.success

browser.fill("uname", "MDSReader").fill("pswd", "MrsDarcy")
await browser.pressButton "Log In", defer()
process.exit(2) unless browser.success

process.stdout.write browser.cookies().get('PHPSESSID') + "\n"
process.exit 0

# console.log "Loading search form..."
# await browser.visit("http://www.jaffindex.com/ff_extsearch.php", defer())
# assert.ok browser.success

# console.log browser.html("form")

# browser.fill("sel_cmplstat", "C")    # complete stories only
# browser.select("sel_novelID", "N001")  # P&P only
# browser.fill("sel_engl", "1")        # English only
# browser.fill("sel_maxwcount", "3000000")  # max word count
# browser.fill("inclall", "1")         # include all data
# console.log "Perfoming search..."
# await browser.pressButton "List Stories", defer()
# assert.ok browser.success

# data = browser.html()
# console.log "#{data.length} bytes received."
# fs.writeFileSync 'results.html', data
# console.log "Done."
