VERSION = 0.1

for win32: 
(add PATH=ruby\bin,
vcvars32 VC6 env, VC7 compiler)
1. go to build_win32 (create 1st)
2. type ruby ..\extconf.rb
3. nmake
4. ruby ..\test.rb
5. nmake install

for unix: (all env build
essential and ruby already setup)
1. go to build_unix (create 1st)
2. type ruby ..\extconf.rb
3. make
4. ruby ..\test.rb
5. make install
