

def parse_global_conf(filename, log):
    """Get connection info from $ZENHOME/etc/global.conf."""
    COMMENT_DELIMETER = "#"
    OPTION_DELIMETER = " "
    parsed_options = {}
    log.debug(
        "Parsing $ZENHOME/etc/global.conf for database connection information"
    )
    global_conf_file = open(filename)
    for line in global_conf_file:
        if COMMENT_DELIMETER in line:
            line, comment = line.split(COMMENT_DELIMETER, 1)
        if OPTION_DELIMETER in line:
            option, value = line.split(OPTION_DELIMETER, 1)
            option = option.strip()
            value = value.strip()
            parsed_options[option] = value
            log.debug("(%s %s)", option, parsed_options[option])
    global_conf_file.close()
    log.debug("Parsing of $ZENHOME/etc/global.conf complete")
    return parsed_options
