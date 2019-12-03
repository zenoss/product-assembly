# render a table of current, develop and latest ZPs based on ZP manifest

import argparse
from github import Github
from subprocess import call
import json
import re
import urllib2
from pprint import pprint
import os

github = Github("my_token")
org = github.get_organization("zenoss")
call(["git", "clone", "git@github.com:zenoss/product-assembly"])
os.chdir("product-assembly")

def get_latest_zp_version(zp_name):
    url = "http://zenpacks.zenoss.eng/requirement/%s" % zp_name
    info = json.loads(urllib2.urlopen(url).read())
    return info['version']

def get_latest_cz_release():
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

    with open("cse/zenpacks.json") as f:
        data = json.load(f)

    for zp in data["install_order"]:
        item = dict()
        item["packaged"] = not zp in data["included_not_installed"]
        item.update(zp_versions[zp])
        zenpacks[zp] = item

    return zenpacks

def main(options):
    unpackaged_style="color: #999999; font-style: italic;"
    last_release_tag, last_release_title = get_latest_cz_release()
    print "Last release of CZ was %s" % (last_release_tag)
    print "Loading ZPs for %s" % (last_release_tag)
    last_cz_zps = get_zenpack_manifest(last_release_tag)
    develop_cz_zps = get_zenpack_manifest("develop")

    regex = re.compile("^.*===")
    print "<table>"
    print "<tr><th>ZenPack</th><th>%s</th><th>Planned Next CZ</th><th>Latest ZP Release</th></tr>" \
                                                                                % (last_release_title)
    unchanged_zps = dict()
    for zenpack in sorted(develop_cz_zps):
        if develop_cz_zps[zenpack]['type'] != "zenpack":
            continue
        if ('requirement' in develop_cz_zps[zenpack]):
            _, dev_ver = develop_cz_zps[zenpack]['requirement'].split("===")
        else:
            dev_ver = "in development"
        if zenpack in last_cz_zps:
            _, rel_ver = last_cz_zps[zenpack]['requirement'].split("===")
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

    #parser.add_argument('tag1', type=str,
    #                    help='Tag of product-assembly to check')

    options = parser.parse_args()
    main(options)
