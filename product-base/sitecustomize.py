import os
import site
import sys
import warnings

sys.setdefaultencoding('utf-8')
site.addsitedir(os.path.join(os.getenv('ZENHOME'), 'ZenPacks'))
site.addsitedir('/var/zenoss/ZenPacks')

# Path to success:
# 1. Ignore all warnings
# 2. Import warning categories (classes derived from Warning)
# 3. Reset warning filters
# 4. Set the desired warning filters.

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
warnings.resetwarnings()

warnings.filterwarnings('ignore', '.*', DeprecationWarning)
for category in _categories:
    warnings.filterwarnings('ignore', category=category)
