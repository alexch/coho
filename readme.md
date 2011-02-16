# Coho
A Cohuman API playground. Usually running at <http://coho.heroku.com>.

# Setup

    gem install bundler
    bundle install
    
# Usage

    rackup
    
or

    rerun rackup

then

    open http://localhost:9292
    

# Deploying to Heroku

Do the normal Heroku thing, then

    heroku config:add COHUMAN_API_KEY=asldjasldkjal
    heroku config:add COHUMAN_API_SECRET=asdfasdfasdf

# Links

* <http://developer.cohuman.com/docs>
* <http://oauth.rubyforge.org/>
* <http://stakeventures.com/articles/2008/02/23/developing-oauth-clients-in-ruby>

# Credits

By Alex Chaffee, based on code samples from Cohuman and the OAuth gem. Do whatever you want with the code. Salmon JPEG stolen from somewhere on the Internet.
