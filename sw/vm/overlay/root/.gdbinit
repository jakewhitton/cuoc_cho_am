# Auto-include python gdb helpers
python
import glob

python_dir = "/root/.gdb"

# Search the python dir for all .py files, and source each
py_files = glob.glob("%s/*.py" % python_dir)
for py_file in py_files:
    gdb.execute('source %s' % py_file)
end
