import os
import site
import sys
import warnings

sys.setdefaultencoding('utf-8')
site.addsitedir(os.path.join(os.getenv('ZENHOME'), 'ZenPacks'))
site.addsitedir('/var/zenoss/ZenPacks')

# Path to filter warnings successfully:
# 1. Copy original/default set of filters
# 2. Ignore all warnings
# 3. Import warning categories (classes derived from Warning)
# 4. Restore original/default set of filters
# 5. Add the additional filters.

_og_filters = warnings.filters[:]
warnings.filterwarnings('ignore', category=Warning)
_categories = []
try:
    from cryptography.utils import CryptographyDeprecationWarning
    _categories.append(CryptographyDeprecationWarning)
except ImportError:
    pass
try:
    from pip._internal.utils.deprecation import PipDeprecationWarning
    _categories.append(PipDeprecationWarning)
except ImportError:
    pass
warnings.filters = _og_filters[:]
for category in _categories:
    warnings.simplefilter('ignore', category=category)
