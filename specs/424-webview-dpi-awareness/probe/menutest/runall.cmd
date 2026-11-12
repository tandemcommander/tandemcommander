@echo off
rem mode 0 = the product's RemeasureMenu, 5 = 424's first version, 1/3/4 = the review's variants
for %%m in (0 5 1 3 4) do "%TEMP%\menutest424.exe" %%m
