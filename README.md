# freerange/deploy

Allows simple, git-based deployment on freerange-compatible servers (see assumptions below)

## How to use

In your project, run:

    $ freerange-deploy setup REPOSITORY HOST [NAME]

This should add a Capfile, config/deploy.rb and config/deploy/production.rb files to the project.  Feel free to edit the deploy.rb and production.rb files as you wish.

When ready, from your project run:

    $ cap production host:setup
    $ cap production deploy:setup

The first command adds a VHOST file to /etc/apache2/sites-available and enables it.  The second does the standard capistrano setup stuff.

For simple apps, you should now be able to deploy:

    $ cap production deploy

## Configuring Redis on server

You can install redis on the destination server by setting this variable in config/deploy.rb

    set :require_redis, true

Now when you run the cap:setup task redis will be installed or you can run this task manually:

    $ cap production setup:redis

Redis is installed with the ubuntu default config living in /etc/redis/redis.conf. It will run on port 6379.

## Assumptions

1. You're deploying as 'deploy'
2. You're deploying to /var/www/<application>
3. The deploy user has write access to /etc/apache2/sites-available
4. The deploy user is a sudoer