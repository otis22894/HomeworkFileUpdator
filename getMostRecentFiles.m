function getMostRecentFiles(homeworkNum)
clc

% Get all the files in the current directory
currentDir = dir();
currentDir = currentDir(~[currentDir.isdir]);
currDirFiles = {currentDir.name};

% Keep all .m files
currMFiles = currentDir(cellfun(@(x) strcmp(x(end-1:end),'.m'),currDirFiles));

%All non .m, .asv, .zip files
currentDir = currentDir(cellfun(@(x) ~strcmp(x(end-1:end),'.m')...
    && ~strcmp(x(end-3:end),'.asv')...
    && ~strcmp(x(end-3:end),'.zip'),...
    currDirFiles));

% If there is not input, try to find the homework file in the current
% directory
if nargin == 0
    % Search for any file of the form "hwXX.m"
    homeworkFile = currDirFiles(~(cellfun(@isempty,regexp(currDirFiles,'hw[0-9][0-9].m'))));
    if ~isempty(homeworkFile)
        % If the file was found, parse the homework number
        homeworkNum = str2double(homeworkFile{1}(3:strfind(homeworkFile{1},'.')-1));
    else
        % If the file was not found, have the user pick the homework with
        % a GUI
        [homeworkNum,ok] = listdlg('ListString',{'Homework 1','Homework 2','Homework 3',...
            'Homework 4','Homework 5','Homework 6',...
            'Homework 7','Homework 8','Homework 9',...
            'Homework 10','Homework 11','Homework 12',...
            'Homework 13'},...
            'SelectionMode','single',...
            'PromptString','Please select the homework number.',...
            'Name','Select Homework Number','ListSize',[300 200]);
        % If the user does something weird, kill the process
        if ~ok
            fprintf(1,'Function Cancelled\n');
            return
        end
    end
end

%Error thrown with invalid homework number inputted by user.
if mod(homeworkNum, 1) ~= 0 || homeworkNum > 13 || homeworkNum < 1
    error('You have inputted an invalid homework number.');
end

% Get the url of the zip file for the current homework
[url, zipFilename] = getZipUrl(homeworkNum);
% If that homework is not available, kill the process and display error
if isempty(url)
    fprintf(1,'---------------------------------------\n');
    fprintf(1,'       Homework %d is unavailable',homeworkNum);
    fprintf(1,'\n---------------------------------------\n');
    return
end

% Save the zip file in the current directory using urlwrite()
urlwrite(url,zipFilename);
% Unzip the homework file to a temp directory
allFiles = unzip(zipFilename,'temp');

mFiles = allFiles(cellfun(@(x) strcmp(x(end-1:end),'.m'),allFiles));
% Get rid of .m files
allFiles = allFiles(cellfun(@(x) ~strcmp(x(end-1:end),'.m'),allFiles));
filesUpdated = false;
updatedFiles = {};
newFiles = {};

% Loop through all files in the zip
for i = 1:length(allFiles)
    % Need this for comparing files quickly
    file_1 = javaObject('java.io.File', allFiles{i});
    % Find the location of the path separators
    if any(allFiles{i} == '/')
        forwardSlashLocs = strfind(allFiles{i},'/') ;
    else %Macs locations are separated by forwardslashes not backslashes
        forwardSlashLocs = strfind(allFiles{i},'\') ;
    end
    
    % Check if the current file exists
    % If it doesn't exist, we need to copy it directly to the current
    % directory
    % If it does exist, we need to check if the current version equals the
    % version we just unzipped
    if ~exist(allFiles{i}(forwardSlashLocs(end)+1:end),'file')
        copyfile(allFiles{i}); % copy file
        filesUpdated = true;   % mark that we copied a file
        newFiles = [newFiles allFiles{i}(forwardSlashLocs(end)+1:end)];
    else
        
        % Create another java object with the file from the zip folder
        file_2 = javaObject('java.io.File', allFiles{i}(forwardSlashLocs(end)+1:end));
        % Use this method because it compares files really fast
        is_equal = javaMethod('contentEquals','org.apache.commons.io.FileUtils',...
            file_1, file_2);
        
        % If the files aren't equal, copy the new one over
        if ~is_equal
            % Delete the old file
            delete(allFiles{i}(forwardSlashLocs(end)+1:end));
            copyfile(allFiles{i});  % copy
            filesUpdated = true;    % Mark that we copied
            updatedFiles = [updatedFiles allFiles{i}(forwardSlashLocs(end)+1:end)];
        end
        
    end
end

%Assigns the hw file name
if homeworkNum < 10
    hw = ['hw0' num2str(homeworkNum) '.m'];
else
    hw = ['hw' num2str(homeworkNum) '.m'];
end

currmfiles = {currMFiles.name};
mtrue = ~isempty(currmfiles(cellfun(@(x) ~isempty(strfind(x,hw)), currmfiles))) || ...
    ~isempty(currmfiles(cellfun(@(x) ~isempty(strfind(x,'ABCs')), currmfiles)));
%Only fix the .m files if the student has some in their current directory
if mtrue
    %Process the m files (hwXX.m and ABCs.m)
    [hwmfileupdate, abcsmfileupdate, mFilesUpdated, newFiles] = processMFiles(mFiles, currmfiles, hw, newFiles);
    %If the hwXX.m file is updated
    if mFilesUpdated
        filesUpdated = true;
        updatedFiles = [updatedFiles hwmfileupdate];
        updatedFiles = [updatedFiles, abcsmfileupdate];
    end
else
    %Copy over the m files (hwXX.m and ABCs.m) if none in their directory
    for i = 1:length(mFiles)
        copyfile(mFiles{i}); % copy file
        filesUpdated = true;   % mark that we copied a file
        newFiles = [newFiles mFiles{i}(forwardSlashLocs(end)+1:end)];
    end
end

% Display what we just did to the user
printResults(filesUpdated,currentDir,updatedFiles,newFiles);

% Remove temp directory and the zip file we downloaded
rmdir('temp','s');
delete(zipFilename);

end

% Gets the last time the files in the current directory were updated
function lastUpdated = getLastUpdatedDate(directory)
allDates = [directory.datenum];
lastUpdated = datestr(max(allDates));
end

% Get the url of the zip folder for the input homework number
function [url,zipFilename] = getZipUrl(hwnum)
lookupData = urlread('http://www.prism.gatech.edu/~rwilliams306/CS1371_HWZips/lookup.txt');
hwLoc = strfind(lookupData,sprintf('%2.2d:',hwnum));
url = strrep(lookupData(hwLoc+4:strfind(lookupData(hwLoc:end),sprintf('\n'))+hwLoc-2),' ','%20');
zipFilename = strrep(url(find(url=='/',1,'last')+1:end),'%20',' ');
end

% Print the results to the user
function printResults(filesUpdated, currentDir, updatedFiles, newFiles)

if ~filesUpdated
    fprintf(1,'-------------------------------------------------------------------------\n');
    fprintf(1,'  All of your files are up to date!\n');
    fprintf(1,'  The files in your directory were last updated on %s', getLastUpdatedDate(currentDir));
    fprintf(1,'\n-------------------------------------------------------------------------\n');
else
    updatedFileString = '';
    for i = 1:length(updatedFiles)
        updatedFileString = [updatedFileString '\t' num2str(i) '. ' updatedFiles{i} '\n'];
    end
    updatedFileString = updatedFileString(1:end-2);
    
    newFileString = '';
    for i = 1:length(newFiles)
        newFileString = [newFileString '\t' num2str(i) '. ' newFiles{i} '\n'];
    end
    newFileString = newFileString(1:end-2);
    
    fprintf(1,repmat('-',1,62));
    if ~isempty(updatedFileString)
        fprintf(1,'\n  The following files have been updated:  \n  ');
        fprintf(1,'%s\n',sprintf(updatedFileString));
    end
    if ~isempty(newFileString)
        fprintf(1,'\n  The following new files have been added to your directory:  \n');
        fprintf(1,'%s\n',sprintf(newFileString));
    end
    fprintf(1,repmat('-',1,62));
    fprintf(1,'\n');
end

end

function [hwmfileupdate, abcsmfileupdate, filesUpdated, newFiles] = processMFiles(mfiles, currmfiles, hw, newFiles)

filesUpdated = false;

%%%%%Working on the hwXX.m file%%%%%%%

%Find the temp hwXX file and the student version
hwXX = mfiles(cellfun(@(x) ~isempty(strfind(x,hw)), mfiles));
hwXXStud = currmfiles(cellfun(@(x) ~isempty(strfind(x,hw)), currmfiles));

if isempty(hwXXStud) %If they don't have a hwXX.m file
    copyfile(hwXX{1}); % copy file
    filesUpdated = true;   % mark that we copied a file
    newFiles = [newFiles hw];
    hwmfileupdate = {}; %This isn't updating, its creating a new file
else
    %Open students hwXX.m file
    linesStudentHwXX = regexp( fileread(hwXXStud{1}), '\n', 'split');
    %Open temp hwXX.m file
    linesHwXX = regexp( fileread(hwXX{1}), '\n', 'split');
    
    %Find a position where students will not have edited the hwXX.m file
    startingRow = find(strncmp(linesHwXX,'% Files provided with this homework:',36));
    
    %Compare the two hwXX.m files from starting point to below
    if ~isequal(linesStudentHwXX(startingRow+1:end), linesHwXX(startingRow+1:end))
        
        %Replace the things below the starting row with new hw file
        hwXX = [linesStudentHwXX(1:startingRow) linesHwXX(startingRow+1:end)];
        fh = fopen(hw, 'w');
        fprintf(fh, '%s\n', hwXX{1:end-1});
        fprintf(fh, '%s', hwXX{end});
        fclose(fh);
        hwmfileupdate = {hw};
        filesUpdated = true;
    else %If they are the same, don't change anything
        hwmfileupdate = {};
    end
end

%%%%%Working on the ABCs.m file%%%%%%%

%Find the temp ABCs files and the student version
ABCs = sort(mfiles(cellfun(@(x) ~isempty(strfind(x,'ABCs')),mfiles)));
ABCsStud = sort(currmfiles(cellfun(@(x) ~isempty(strfind(x,'ABCs')),currmfiles)));
abcsmfileupdate = {};
for i = 1:length(ABCs)
    if any(ABCs{i} == '/')
        forwardSlashLocs = strfind(ABCs{i},'/') ;
    else %Macs locations are separated by forwardslashes not backslashes
        forwardSlashLocs = strfind(ABCs{i},'\') ;
    end
    
    if ~exist(ABCs{i}(forwardSlashLocs(end)+1:end),'file') %If they don't have the specific ABCs.m file
        copyfile(ABCs{i}); % copy file
        filesUpdated = true;   % mark that we copied a file
        newFiles = [newFiles ABCs{i}(forwardSlashLocs(end)+1:end)]; 
    else
        %Open ABCs.m files
        student_ABCs = fileread(ABCsStud{i});
        soln_ABCs = fileread(ABCs{i});
        
        student_questions = regexp(student_ABCs,'(%(\n|.)*?\n)(?!%)','match');
        soln_questions = regexp(soln_ABCs,'(%(\n|.)*?\n)(?!%)','match');
        
        if ~isequal(student_questions,soln_questions) 
            
            student_code = regexp(student_ABCs,'(^[^%].*)','lineanchors','dotexceptnewline','match');
            
            if isequal(length(student_questions),length(soln_questions))
                
                student_code_start = regexp(student_ABCs,'(^[^%].*)','lineanchors','dotexceptnewline','start');
                student_questions_start = regexp(student_ABCs,'(%(\n|.)*?\n)(?!%)','start');
                
                outputString = '';
                while ~isempty(student_code_start) && ~isempty(student_questions_start)
                    if student_code_start(1) < student_questions_start(1)
                        outputString = [outputString student_code{1}];
                        student_code_start = student_code_start(2:end);
                        student_code = student_code(2:end);
                    else
                        outputString = [outputString soln_questions{1}];
                        student_questions_start = student_questions_start(2:end);
                        soln_questions = soln_questions(2:end);
                    end
                end
                for k = 1:length(soln_questions)
                    outputString = [outputString soln_questions{k}];
                end
                for k = 1:length(student_code)
                    outputString = [outputString student_code{k}];
                end
                fh = fopen(ABCsStud{i},'w');
                fprintf(fh,'%s',outputString);
                fclose(fh);
                filesUpdated = true;
                abcsmfileupdate = [abcsmfileupdate , ABCs{i}(forwardSlashLocs(end)+1:end)];
            else
                warning('Could not update ABCs file. If the ABCs file was updated, you should re-download it from TSquare');
            end
        end
    end
end
end