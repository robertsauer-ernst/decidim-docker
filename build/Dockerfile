# Decidim 0.31.0 Custom Build - Ruby 3.3
FROM ruby:3.3-slim-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libpq-dev \
    imagemagick \
    libvips-dev \
    libicu-dev \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

WORKDIR /app

# Install decidim generator (includes decidim-dev for generation)
RUN gem install decidim -v 0.31.0 && \
    gem install decidim-dev -v 0.31.0

# Generate new Decidim application
RUN decidim my_app

WORKDIR /app/my_app

# Copy add_gems script and run it
COPY add_gems.rb /tmp/add_gems.rb
RUN sed -i /decidim-dev/d Gemfile && \
    ruby /tmp/add_gems.rb

# Install gems for production only
RUN bundle config set --local without "development test" && \
    bundle install --jobs 4

# Precompile assets
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=placeholder_for_asset_compilation
ENV RAILS_SERVE_STATIC_FILES=true

RUN bundle exec rails assets:precompile

# Production image
FROM ruby:3.3-slim-bookworm

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    imagemagick \
    libvips42 \
    libicu72 \
    libyaml-0-2 \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js runtime
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built application
COPY --from=builder /app/my_app /app
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy config files
COPY database.yml /app/config/database.yml
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

# Create directories
RUN mkdir -p tmp/pids tmp/cache log public/uploads storage

# Set environment
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

EXPOSE 3000

ENTRYPOINT ["/app/entrypoint.sh"]
