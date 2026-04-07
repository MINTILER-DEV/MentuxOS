return [[
let outputId = envGet("TERM_OUTPUT");
let lineId = envGet("TERM_LINE");
let line = "";

guiAppend(outputId, "Mentux Command Interpreter ready");
guiAppend(outputId, concat("PWD=", envGet("PWD")));
guiAppend(outputId, "Builtins: help, ls, cd, pwd, touch, write, append, cat, rm, mkdir, mv, ps, kill, which, motd, clear, exit");
guiAppend(outputId, "Apps: curl, ping, hello, notepad, code, browser, mtsum, settings, mtxdthost");
guiAppend(outputId, "Redirection: <builtin> ... >> <path>");
guiSetText(lineId, concat(concat(envGet("PWD"), " $ "), line));

while true {
	let event = inputWait();
	let eventType = get(event, 1);
	let eventValue = get(event, 2);

	if eventType == "char" {
		line = concat(line, eventValue);
		guiSetText(lineId, concat(concat(envGet("PWD"), " $ "), line));
	} else {
		if eventType == "backspace" {
			if len(line) > 0 {
				line = substr(line, 1, len(line) - 1);
				guiSetText(lineId, concat(concat(envGet("PWD"), " $ "), line));
			}
		} else {
			if eventType == "escape" {
				line = "";
				guiSetText(lineId, concat(concat(envGet("PWD"), " $ "), line));
			} else {
				if eventType == "enter" {
					let submittedLine = line;
					line = "";
					guiAppend(outputId, concat(concat(envGet("PWD"), " $ "), submittedLine));

					let args = listNew();
					let current = "";
					let index = 1;
					let lineLength = len(submittedLine);
					while index <= lineLength {
						let ch = charAt(submittedLine, index);
						if ch == " " {
							if len(current) > 0 {
								push(args, current);
								current = "";
							}
						} else {
							current = concat(current, ch);
						}
						index = index + 1;
					}
					if len(current) > 0 {
						push(args, current);
					}

					if len(args) > 0 {
						let redirectIndex = 0;
						let scanIndex = 1;
						while scanIndex <= len(args) {
							if get(args, scanIndex) == ">>" {
								redirectIndex = scanIndex;
							}
							scanIndex = scanIndex + 1;
						}

						let redirectActive = false;
						let redirectPath = "";
						if redirectIndex > 0 {
							if redirectIndex < len(args) {
								redirectPath = resolvePath(get(args, redirectIndex + 1));
								if statKind(redirectPath) == "dir" {
									guiAppend(outputId, "redirection target cannot be a directory");
								} else {
									redirectActive = true;
								}
							} else {
								guiAppend(outputId, "missing redirection target");
							}
						}

						let commandArgs = listNew();
						let argLimit = len(args);
						if redirectIndex > 0 {
							argLimit = redirectIndex - 1;
						}
						let copyIndex = 1;
						while copyIndex <= argLimit {
							push(commandArgs, get(args, copyIndex));
							copyIndex = copyIndex + 1;
						}

						if len(commandArgs) > 0 {
							let cmd = get(commandArgs, 1);
							let handled = false;

							if cmd == "help" {
								handled = true;
								if redirectActive == true {
									appendFile(redirectPath, "Builtins: help, ls, cd, pwd, touch, write, append, cat, rm, mkdir, mv, ps, kill, which, motd, clear, exit\n");
									appendFile(redirectPath, "Apps: curl, ping, hello, notepad, code, browser, mtsum, settings, mtxdthost\n");
									appendFile(redirectPath, "Redirection: <builtin> ... >> <path>\n");
								} else {
									guiAppend(outputId, "Builtins: help, ls, cd, pwd, touch, write, append, cat, rm, mkdir, mv, ps, kill, which, motd, clear, exit");
									guiAppend(outputId, "Apps: curl, ping, hello, notepad, code, browser, mtsum, settings, mtxdthost");
									guiAppend(outputId, "Redirection: <builtin> ... >> <path>");
								}
							}

							if handled == false {
								if cmd == "pwd" {
									handled = true;
									if redirectActive == true {
										appendFile(redirectPath, concat(envGet("PWD"), "\n"));
									} else {
										guiAppend(outputId, envGet("PWD"));
									}
								}
							}

							if handled == false {
								if cmd == "motd" {
									handled = true;
									let motdValue = readFile("/etc/motd.txt");
									if redirectActive == true {
										appendFile(redirectPath, concat(motdValue, "\n"));
									} else {
										guiAppend(outputId, motdValue);
									}
								}
							}

							if handled == false {
								if cmd == "clear" {
									handled = true;
									guiSetText(outputId, "");
								}
							}

							if handled == false {
								if cmd == "cd" {
									handled = true;
									let target = envGet("HOME");
									if len(commandArgs) > 1 {
										target = resolvePath(get(commandArgs, 2));
									}
									if statKind(target) == "dir" {
										envSet("PWD", target);
										if redirectActive == true {
											appendFile(redirectPath, concat(concat("PWD=", target), "\n"));
										} else {
											guiAppend(outputId, concat("PWD=", target));
										}
									} else {
										guiAppend(outputId, "Directory not found");
									}
								}
							}

							if handled == false {
								if cmd == "ls" {
									handled = true;
									let target = envGet("PWD");
									if len(commandArgs) > 1 {
										target = resolvePath(get(commandArgs, 2));
									}
									let kind = statKind(target);
									if kind == "dir" {
										let entries = listDir(target);
										let entryIndex = 1;
										while entryIndex <= len(entries) {
											let entryLine = get(entries, entryIndex);
											if redirectActive == true {
												appendFile(redirectPath, concat(entryLine, "\n"));
											} else {
												guiAppend(outputId, entryLine);
											}
											entryIndex = entryIndex + 1;
										}
									} else {
										if kind == "file" {
											if redirectActive == true {
												appendFile(redirectPath, concat(target, "\n"));
											} else {
												guiAppend(outputId, target);
											}
										} else {
											guiAppend(outputId, "Path not found");
										}
									}
								}
							}

							if handled == false {
								if cmd == "touch" {
									handled = true;
									if len(commandArgs) < 2 {
										guiAppend(outputId, "usage: touch <path>");
									} else {
										let path = resolvePath(get(commandArgs, 2));
										if statKind(path) == "dir" {
											guiAppend(outputId, "touch target is a directory");
										} else {
											if exists(path) == false {
												writeFile(path, "");
											}
										}
									}
								}
							}

							if handled == false {
								if cmd == "write" {
									handled = true;
									if len(commandArgs) < 2 {
										guiAppend(outputId, "usage: write <path> [text]");
									} else {
										let path = resolvePath(get(commandArgs, 2));
										let content = "";
										let textIndex = 3;
										while textIndex <= len(commandArgs) {
											if len(content) > 0 {
												content = concat(content, " ");
											}
											content = concat(content, get(commandArgs, textIndex));
											textIndex = textIndex + 1;
										}
										writeFile(path, content);
									}
								}
							}

							if handled == false {
								if cmd == "append" {
									handled = true;
									if len(commandArgs) < 2 {
										guiAppend(outputId, "usage: append <path> [text]");
									} else {
										let path = resolvePath(get(commandArgs, 2));
										let content = "";
										let textIndex = 3;
										while textIndex <= len(commandArgs) {
											if len(content) > 0 {
												content = concat(content, " ");
											}
											content = concat(content, get(commandArgs, textIndex));
											textIndex = textIndex + 1;
										}
										appendFile(path, content);
									}
								}
							}

							if handled == false {
								if cmd == "cat" {
									handled = true;
									if len(commandArgs) < 2 {
										guiAppend(outputId, "usage: cat <path> [path...]");
									} else {
										let pathIndex = 2;
										while pathIndex <= len(commandArgs) {
											let path = resolvePath(get(commandArgs, pathIndex));
											let kind = statKind(path);
											if kind == "file" {
												let fileText = fileInfo(path);
												if redirectActive == true {
													appendFile(redirectPath, concat(fileText, "\n"));
												} else {
													guiAppend(outputId, fileText);
												}
											} else {
												if kind == "dir" {
													guiAppend(outputId, concat(path, " is a directory"));
												} else {
													guiAppend(outputId, concat(path, " not found"));
												}
											}
											pathIndex = pathIndex + 1;
										}
									}
								}
							}

							if handled == false {
								if cmd == "rm" {
									handled = true;
									if len(commandArgs) < 2 {
										guiAppend(outputId, "usage: rm <path>");
									} else {
										let path = resolvePath(get(commandArgs, 2));
										if exists(path) == true {
											deletePath(path);
										} else {
											guiAppend(outputId, "Path not found");
										}
									}
								}
							}

							if handled == false {
								if cmd == "mkdir" {
									handled = true;
									if len(commandArgs) < 2 {
										guiAppend(outputId, "usage: mkdir <path>");
									} else {
										makeDir(resolvePath(get(commandArgs, 2)));
									}
								}
							}

							if handled == false {
								if cmd == "mv" {
									handled = true;
									if len(commandArgs) < 3 {
										guiAppend(outputId, "usage: mv <source> <destination>");
									} else {
										let sourcePath = resolvePath(get(commandArgs, 2));
										let destinationPath = resolvePath(get(commandArgs, 3));
										if exists(sourcePath) == true {
											movePath(sourcePath, destinationPath);
										} else {
											guiAppend(outputId, "Source path not found");
										}
									}
								}
							}

							if handled == false {
								if cmd == "ps" {
									handled = true;
									let processes = listProcesses();
									let procIndex = 1;
									while procIndex <= len(processes) {
										let procLine = get(processes, procIndex);
										if redirectActive == true {
											appendFile(redirectPath, concat(procLine, "\n"));
										} else {
											guiAppend(outputId, procLine);
										}
										procIndex = procIndex + 1;
									}
								}
							}

							if handled == false {
								if cmd == "kill" {
									handled = true;
									if len(commandArgs) < 2 {
										guiAppend(outputId, "usage: kill <pid>");
									} else {
										let targetPid = toNumber(get(commandArgs, 2));
										if killProcess(targetPid, 143) == true {
											if redirectActive == true {
												appendFile(redirectPath, concat(concat("killed ", targetPid), "\n"));
											} else {
												guiAppend(outputId, concat("killed ", targetPid));
											}
										} else {
											guiAppend(outputId, "PID not found");
										}
									}
								}
							}

							if handled == false {
								if cmd == "which" {
									handled = true;
									if len(commandArgs) < 2 {
										guiAppend(outputId, "usage: which <command>");
									} else {
										let resolved = resolveExec(get(commandArgs, 2));
										if resolved == false {
											guiAppend(outputId, "Command not found");
										} else {
											if redirectActive == true {
												appendFile(redirectPath, concat(resolved, "\n"));
											} else {
												guiAppend(outputId, resolved);
											}
										}
									}
								}
							}

							if handled == false {
								if cmd == "exit" {
									handled = true;
									exit(0);
								}
							}

							if handled == false {
								if redirectActive == true {
									guiAppend(outputId, "redirection is currently supported for shell builtins only");
								} else {
									let resolved = resolveExec(cmd);
									if resolved == false {
										let directPath = resolvePath(cmd);
										if statKind(directPath) == "file" {
											resolved = directPath;
										} else {
											let directMain = resolvePath(concat(cmd, "/main.mtx"));
											if statKind(directMain) == "file" {
												resolved = directMain;
											}
										}
									}
									if resolved == false {
										guiAppend(outputId, "Command not found");
									} else {
										let childArgs = sliceList(commandArgs, 2);
										exec(resolved, childArgs);
									}
								}
							}
						}
					}

					guiSetText(lineId, concat(concat(envGet("PWD"), " $ "), line));
				}
			}
		}
	}
}
]]
