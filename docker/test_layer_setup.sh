#!/bin/sh

setup_date_server() {
    # Start redis DB and add some test values
    /usr/bin/redis-server &
    sleep 2
    redis-cli -n 0 DEL layer:date_test
    redis-cli -n 0 SET layer:date_test:default "2015-01-01"
    redis-cli -n 0 SADD layer:date_test:periods "2015-01-01/2017-01-01/P1Y"
    redis-cli -n 0 SAVE

    # Copy config stuff
    cp oe2_test_date_service.conf /etc/httpd/conf.d
    mkdir -p /var/www/html/date_service
    cp date_service.lua /var/www/html/date_service/date_service.lua
}

setup_mod_mrf_static() {
    mkdir -p /var/www/html/mrf_endpoint/static_test/default/tms
    cp test_imagery/static_test* /var/www/html/mrf_endpoint/static_test/default/tms/
    cp oe2_test_mod_mrf_static.conf /etc/httpd/conf.d
    cp oe2_test_mod_mrf_static_layer.config /var/www/html/mrf_endpoint/static_test/default/tms/
    /usr/sbin/httpd -k restart
    sleep 2

    # Test a tile
    TILE=($(curl -s http://localhost/mrf_endpoint/static_test/default/tms/0/0/0.jpg | md5sum ))
    if [ "$TILE" != "41758bf9df2af462649dd5458c5a51f0" ]
    then
        echo "ERROR: error with mod_mrf static layer" >&2
        ERR=1
    fi
}

setup_mod_mrf_date() {
    mkdir -p /var/www/html/mrf_endpoint/date_test/default/tms
    cp test_imagery/date_test* /var/www/html/mrf_endpoint/date_test/default/tms
    cp oe2_test_mod_mrf_date.conf /etc/httpd/conf.d
    cp oe2_test_mod_mrf_date_layer.config /var/www/html/mrf_endpoint/date_test/default/tms/
    /usr/sbin/httpd -k restart
    sleep 2

    # Test that tiles look okay
    DEFAULT_TILE=($(curl -s http://localhost/mrf_endpoint/date_test/default/default/tms/0/0/0.jpg | md5sum ))
    SNAP_TILE=($(curl -s http://localhost/mrf_endpoint/date_test/default/2016-06-01/tms/0/0/0.jpg | md5sum ))
    if [[ "$DEFAULT_TILE" != "332a632f5642836001e7ae1613253254" ]] && [[ "$SNAP_TILE" != "43dbf8bd926af88997c6f739aa9e043e" ]]
    then
        echo "ERROR: error with mod_mrf date layer" >&2
        ERR=1
    fi
}

setup_mod_reproject_date() {
    mkdir -p /var/www/html/reproject_endpoint/date_test/default/tms
    cp oe2_test_mod_reproject_date.conf /etc/httpd/conf.d
    cp oe2_test_mod_reproject_layer_source*.config /var/www/html/reproject_endpoint/date_test/default/tms/oe2_test_mod_reproject_date_layer_source.config
    cp oe2_test_mod_reproject_date*.config /var/www/html/reproject_endpoint/date_test/default/tms/
    /usr/sbin/httpd -k restart
    sleep 2

    # Test that tiles look okay
    DEFAULT_TILE=($(curl -s http://localhost/reproject_endpoint/date_test/default/default/tms/0/0/0.jpg | md5sum ))
    SNAP_TILE=($(curl -s http://localhost/reproject_endpoint/date_test/default/2016-06-01/tms/0/0/0.jpg | md5sum ))
    if [[ "$DEFAULT_TILE" != "13cfa6b625884bb8e59bc8944a2b9e1b" ]] && [[ "$SNAP_TILE" != "f9471b34e8c3ba22713d346476e945dd" ]]
    then
        echo "ERROR: error with mod_reproject date layer" >&2
        ERR=1
    fi
}

setup_mod_reproject_static() {
    mkdir -p /var/www/html/reproject_endpoint/static_test/default/tms
    cp oe2_test_mod_reproject_static.conf /etc/httpd/conf.d
    cp oe2_test_mod_reproject_layer_source*.config /var/www/html/reproject_endpoint/static_test/default/tms/oe2_test_mod_reproject_static_layer_source.config
    cp oe2_test_mod_reproject_static*.config /var/www/html/reproject_endpoint/static_test/default/tms/
    /usr/sbin/httpd -k restart
    sleep 2

    # Test that tiles look okay
    TILE=($(curl -s http://localhost/reproject_endpoint/static_test/default/tms/0/0/0.jpg | md5sum))
    if [ "$TILE" != "7925f956cafaed57bf440ada01a333c6" ]
    then
        echo "ERROR: error with mod_reproject static layer" >&2
        ERR=1
    fi
}

setup_mod_mrf_static
setup_date_server
setup_mod_mrf_date
setup_mod_reproject_date
setup_mod_reproject_static

if [ -z "$ERR" ]
then
    echo "No errors found, tests passed!"
fi