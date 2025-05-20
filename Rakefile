require 'rake'
require 'erb'
require 'psych'
require 'redcarpet'

POSTS_DIR = 'posts'
OUT_DIR = 'public'
TEMPLATE_DIR = 'layout'

desc 'Build all posts'
task :build do
  Dir.glob(File.join(POSTS_DIR, '*')).each do |post_path|
    config = Psych.safe_load_file File.join(post_path, 'config.yml'), permitted_classes: [Date]
    title = config.fetch 'title', 'Untitled'
    date = config.fetch 'date', Date.today
    layout = ERB.new File.read(File.join(TEMPLATE_DIR, config.fetch('layout', 'default.erb')))
    markdown = File.read File.join(post_path, 'post.md')

    md_opts = {
      autolink: false,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      footnotes: true,
      underline: true,
      highlight: true,
      superscript: true,
    }
    renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, **md_opts)
    content = renderer.render(markdown)
    html = layout.result(binding)

    filename = File.join(OUT_DIR, config['output'])
    File.write filename, html
    puts "Built post ##{config['index']}: #{filename}"
  end
end

task :default => :build
