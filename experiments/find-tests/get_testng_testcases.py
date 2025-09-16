#!/usr/bin/env python3

import os
import sys
import xml.etree.ElementTree as ET

module = os.getenv('MMMP_MODULE', '')


if len(sys.argv) != 2 or not os.path.isfile(sys.argv[1]):
    print('Usage: python get_testng_testcases.py <testng-results.xml>')
    exit(1)

with open(sys.argv[1]) as f:
    tree = ET.parse(f)
    for suite in tree.getroot().findall('suite'):
        for test in suite.findall('test'):
            for klass in test.findall('class'):
                classname = klass.get('name')
                for testmethod in klass.findall('test-method'):
                    if not module:
                        print(classname + '#' + testmethod.get('name'))
                    else:
                        print(module + '#' + classname + '#' + testmethod.get('name'))
