#!/usr/bin/env bash

function _mon_{{opt}}() {
    echo "mon: {{cmd}}: '{{opt}}' not implemented" >&2
    return 1
}
