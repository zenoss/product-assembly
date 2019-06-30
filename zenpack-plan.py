# render a table of current, develop and latest ZPs based on ZP manifest

import argparse
from github import Github
from subprocess import call
import json
import re
import urllib2
import os


def get_latest_zp_version(zp_name):
    url = "http://zenpacks.zenoss.eng/requirement/%s" % zp_name
    info = json.loads(urllib2.urlopen(url).read())
    return info['version']

def get_latest_cz_release(org):
    repo = org.get_repo("product-assembly")
    release = repo.get_latest_release()
    return release.tag_name, release.title

def get_zenpack_manifest(tag):
    call(["git", "checkout", tag])
    call(["git", "pull"])
    with open("zenpack_versions.json") as f:
       data = json.load(f) 

    zenpacks = dict()
    zp_versions = {i["name"]:i for i in data}

    with open("resmgr/zenpacks.json") as f:
        data = json.load(f)

    for zp in (data["install_order"] + data["included_not_installed"]):
        item = dict()
        item["packaged"] = not zp in data["included_not_installed"]
        item.update(zp_versions[zp])
        zenpacks[zp] = item

    return zenpacks

def main(options):
    unpackaged_style="color: #999999; font-style: italic;"

    github = Github(options.ghuser, options.ghpassword)
    org = github.get_organization("zenoss")

    call(["git", "clone", "git@github.com:zenoss/product-assembly"]) 
    os.chdir("product-assembly")
    last_release_tag, last_release_title = get_latest_cz_release(org)
    last_release_tag = options.base

    print "Loading ZPs for %s" % (last_release_tag)
    last_cz_zps = get_zenpack_manifest(last_release_tag)
    develop_cz_zps = get_zenpack_manifest("support/6.x")

    regex = re.compile("^.*===")
    print "<table>"
    print "<tr><th>ZenPack</th><th>%s</th><th>%s</th><th>Latest ZP Release</th></tr>" \
                                                                                % (options.base, options.compare)
    unchanged_zps = dict()
    for zenpack in sorted(develop_cz_zps):
        if develop_cz_zps[zenpack]['type'] != "zenpack":
            continue
        if ('requirement' in develop_cz_zps[zenpack]):
            _, dev_ver = re.split("=*",develop_cz_zps[zenpack]['requirement'])
        else:
            dev_ver = "in development"    
        if "*" in dev_ver:
            dev_ver = "in development"
        if zenpack in last_cz_zps:
            _, rel_ver = re.split("=*",last_cz_zps[zenpack]['requirement'])
        else:
            new_zp = {"packaged":"not present"}
            last_cz_zps[zenpack] = new_zp
            rel_ver = "not present"
        latest_ver = get_latest_zp_version(zenpack)
        if dev_ver == rel_ver == latest_ver:
            unchanged_zps[zenpack] = dev_ver
        else:
            print '<tr>'
            style = "" if last_cz_zps[zenpack]['packaged'] else unpackaged_style
            print '<td>%s</td><td style="%s">%s</td>' % (zenpack,style,rel_ver)
            style = "" if develop_cz_zps[zenpack]['packaged'] else unpackaged_style
            print '<td style="%s">%s' % (style, dev_ver) 
            print "</td><td>%s</td></tr>" % (latest_ver)
    print "</table>"
    print "<table>"
    print "<tr><th>ZenPack</th><th>Version</th></tr>" 
    for zenpack in sorted(unchanged_zps):
        style = "" if develop_cz_zps[zenpack]['packaged'] else unpackaged_style
        print '<tr><td style="%s">%s</td><td style="%s">%s</td></tr>' \
                                % (style, zenpack, style, unchanged_zps[zenpack])
    
    print "</table>"

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Build ZenPack Plan')
    parser.add_argument('--ghuser', type=str, 
                        help='Github Username')
    parser.add_argument('--ghpassword', type=str, 
                        help='Github Password')

    parser.add_argument('--product', type=str, 
                        help='Product = cse or resmgr')
    parser.add_argument('--base', type=str, 
                        help='Base branch for comparison')
    parser.add_argument('--compare', type=str, 
                        help='Commit/tag to compare with base')
    options = parser.parse_args()
    main(options)
