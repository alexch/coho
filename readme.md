# Coho
A Cohuman API playground

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

# Credits

By Alex Chaffee, based on code samples from Cohuman and the OAuth gem. Do whatever you want with the code. Salmon JPEG stolen from somewhere on the Internet.
