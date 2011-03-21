class Page < Erector::Widgets::Page
  needs :session, :request, :result => nil, :query => nil

  external :style, <<-CSS
  body { font-family:sans-serif;}
  table { border: 1px solid gray; border-spacing: 0; }
  td, th { 
    border: 1px solid gray; 
    padding: .5em .25em;
    vertical-align: top;
    text-align: left;
    max-width: 80em;
  }
  th { background: #ededed; }

  pre { margin: 0; 
    max-height: 20em; overflow-y: auto;
    max-width: 60em; overflow-x: auto;
    }
  CSS

  def page_title
    "Coho"
  end
  
  def logo
    img :src => "coho_salmon.jpg", :width => (831/2), :height => (347/2), :align=>"left"
    br; br; br
    h1 "Coho!"
    i do
      text "Swimming upstream in the "
      a "Cohuman API", :href => "http://developer.cohuman.com"
    end
    br :clear => true, :style => "clear:both;"
  end

  def body_content
    ribbon
    logo
    hr
    button_form "/authorize", "Sign In To Cohuman"
    if @session[:access_token]
      button_form "/logout", "Sign Out"
      button_form "/tasks", "List Tasks"
      button_form "/users", "List Users"
      button_form "/projects", "List Projects"
    end
    if @query or @result
      hr
      table do
        if @query
          tr do
            th "Query:"
            td { pre @query }
          end
        end
        if @result
          tr { th "Result", :colspan => 2 }
          tr { td(:colspan => 2) { pre {
            out = ""
            PP.pp(@result, out)
            text out
          } } }
        end
      end
    end
    hr
    session_table
    hr
    env_table
    hr
  end

  def session_table
    hash_table("Session", @session)
  end

  def env_table
    hash_table "Rack Environment", @request.env
  end

  def hash_table(name, hash)
    table do
      tr do
        th name, :colspan => 2
      end
      if hash.empty?
        td(:colspan => 2) {
          rawtext nbsp*5 
          text "[empty]"
          rawtext nbsp*5 
        }
      else
        hash.each_pair do |k,v|
          tr do
            td k.to_s
            td do
              if v
                pre do
                  out = ""
                  PP.pp(v, out)
                  text out
                end
              else
                rawtext nbsp
              end
            end            
          end
        end
      end
    end
    
  end

  def button_form action, label
    form :action => action, :method => "get" do
      input :type=> :submit, :value => label
    end
  end
  
  # thanks to https://github.com/blog/273-github-ribbons
  def ribbon
    rawtext <<-HTML
    <a href="http://github.com/alexch/coho"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://assets1.github.com/img/7afbc8b248c68eb468279e8c17986ad46549fb71?repo=&url=http%3A%2F%2Fs3.amazonaws.com%2Fgithub%2Fribbons%2Fforkme_right_darkblue_121621.png&path=" alt="Fork me on GitHub"></a>
    HTML
  end
  
end
