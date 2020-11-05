from setuptools import setup, find_packages
from distutils.spawn import find_executable

setup(
  name="telegram_check",
  zip_safe=False, # https://mypy.readthedocs.io/en/latest/installed_packages.html
  scripts=['telegram_check.py', 'telegram_send.py'],
  python_requires='>=3.6',
)



