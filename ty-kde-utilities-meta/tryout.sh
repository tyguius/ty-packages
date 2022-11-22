#!/bin/bash

depends=($(grep -v "^#" "depends"))

echo "${depends[@]}"
