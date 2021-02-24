from setuptools import setup, find_packages
from distutils.spawn import find_executable

setup(
  name="python_scripts",
  zip_safe=False, # https://mypy.readthedocs.io/en/latest/installed_packages.html
  package_dir={'':'lib'},
  packages=find_packages(where='lib'),
  scripts=['telegram_check.py', 'telegram_send.py', 'dongleman_send.py',
           'dongleman_daemon.py', 'dongleman_spool.py', 'ari_test.py'],
  python_requires='>=3.6',
)



