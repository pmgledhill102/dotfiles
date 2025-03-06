# python-setup.ps1
# - Configure Python and Jupyter Notebooks on a Windows device

# Expect Python, Python Launcher and Anaconda to be installed
# - winget install --id="Python.Python.2" --exact --silent
# - winget install --id="Python.Python.3.13" --exact --silent
# - winget install --id="Python.Launcher" --exact --silent
# - winget install --id="Anaconda.Anaconda3" --exact --silent

# Configure Jupyter in an isolated environment
# Restart of the terminal is required after running the following commands
&"$HOME\anaconda3\Scripts\conda.exe" init

# And then run these...
conda create --name jupyter_env python=3.13 --yes
conda activate jupyter_env
conda install jupyterlab

# Microsoft Learn Article here:
# https://code.visualstudio.com/docs/datascience/jupyter-notebooks
