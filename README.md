# crypto-tracker.rb

## Create database user and database
```
createuser -s postgres
createuser -U postgres rb_crypto_tracker
createdb -U postgres -O rb_crypto_tracker rb_crypto_tracker_production
createdb -U postgres -O rb_crypto_tracker rb_crypto_tracker_test
createdb -U postgres -O rb_crypto_tracker rb_crypto_tracker_development
```

## Connect to Postgres database
```
psql -d rb_crypto_tracker_development -U rb_crypto_tracker
```