# Google Drive Transfer

Tool for google drive data transfering to another google account.

# Introduction

## 1. Authorization

First, let create google API authorization -> [On behalf of you(command line authorization)](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md#on-behalf-of-you-command-line-authorization)

You should remember `client_id` and `client_secret`.

## 2. Set up

```
$ bundle install
$ bundle exec bin/google_drive_transfer setup
  Input your Google API client_id:
  #{YOUR_CLIENT_ID}
  Input your Google API client_secret:
  #{YOUR_CLIENT_SECRET}
```

# Execution

```
$ PARALLEL_NUM=4 bundle exec bin/google_drive_transfer start
```

The first login should be __transfer source__ google account,
second login should be __transfer target__ google account.

## Transfer strategy

If you would like to skip some folders to transfer,
you can define folders name at `transfer_strategy.yml`.

## Error log

Files that fail to transfer will be recorded in the error log on `./log`

# Licence

[MIT License](https://github.com/tanukiti1987/google_drive_transfer/blob/master/LICENSE.txt)
