#!/usr/bin/env bash

function _mon_{{opt}}() {
    echo "{{cmd}}: '{{opt}}' not implemented" >&2
    return 1
}
