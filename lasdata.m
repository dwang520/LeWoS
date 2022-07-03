classdef lasdata < handle
    %lasdata LAS data reader / writer / converter
    %   Reads LAS files in format 1.0,1.1,1.2,1.3 and 1.4, supports point 
    %   formats 0-10. This tool is intended for quick manual LAS file open,
    %   edit, repair and saving.
    %
    %   Load LAS file into class with c = lasdata('file.las');
    %   Default load only loads xyz coordinates. Additional variables can
    %   be loaded with the accessor functions get_(variable name).
    %
    %   Not much checks are made for the modified data. Feel free to modify 
    %   class member variables, but don't break your data. ;)
    %
    %   Data is written in the format set in the class header, except
    %   that the target format can be given with the write_las function.
    %
    %   Copyright (C) Teemu Kumpumki / Tampere University of Technology 2014
	%	Licence: see the included BSD licence.
    properties
        x; %X coordinate
        y; %Y coordinate
        z; %Z coordinate
        intensity; %Return intensity
        bits; %Data in bitfields
        bits2;%Data in bitfields from 1.4+
        classification; %Classification
        user_data; %User data
        scan_angle; %Scan angle
        point_source_id; %Point source id
        gps_time; %GPS timestamp
        red; %Red color channel
        green; %Green color channel
        blue; %Blue color channel
        nir; %Near infrared color channel
        extradata; %extra data found at the end of the point record

        Xt; %Waveform line x(t) parameter
        Yt; %Waveform line y(t) parameter
        Zt; %Waveform line z(t) parameter
        wave_return_point; %Time in picoseconds from wave recording start
        
        wave_packet_descriptor; %Waveform packet descriptor index
        wave_byte_offset; %Byte offset to waveform data (in/ext file)
        wave_packet_size; %Size of single waveform packet
        
        header; %Contain LAS header
        variablerecords; %Contain LAS variable records
        extendedvariables; %Contains LAS extended variable records
        
        selection; %Filtering logical index
        
        wavedescriptors; %Waveform descriptor structures
        filename; %Name of the datafile loaded       
    end
    
    properties (Access=private)
        originalname; 
        waveformfile; %name of the waveform file
        waveformfilefid;
        isLAZ; %laz compression check (to delete temporary file in destructor)
    end
    
methods (Access=public)
    
    function obj = lasdata(filename,command)
        obj.waveformfilefid = -1;
        obj.filename = filename;
        obj.originalname = filename;
        
        if exist('command','var') && ischar(command)
            if strcmp(command,'createemptyobj')
                obj.createemptyheader();
                disp('Empty object created, please set header & data values and then write las file. You need to read the LAS specification for header values in each format.')
            elseif strcmp(command,'loadall')
                obj.las_read(filename);
                %try reading all variables
                obj.read_intensity();
                obj.read_classification();
                obj.read_user_data();
                obj.read_scan_angle();
                obj.read_point_source_id();
                obj.read_point_wave_info();
                obj.read_gps_time();                
                obj.read_bits(); 
                obj.read_extradata(); 
                obj.read_color(); 
            else
                error(['Invalid command: ' command]);
            end
        else
            obj.las_read(filename);
        end
    end    
    
    function delete(obj)
        if obj.waveformfilefid > 2
            fclose(obj.waveformfilefid);
        end
        if obj.isLAZ 
            delete([obj.filename]);
        end
    end
        
    function obj = normalize_xyz( obj )
        if isempty(obj.x)
            warning('No data loaded.')
            return;
        end
        obj.x = double(obj.x) * obj.header.scale_factor_x + obj.header.x_offset;
        obj.y = double(obj.y) * obj.header.scale_factor_y + obj.header.y_offset;
        obj.z = double(obj.z) * obj.header.scale_factor_z + obj.header.z_offset;
    end
    
    function data = toint32_xyz( obj )
        if isempty(obj.x)
            warning('No data loaded.')
            return;
        end
        if isa(obj.x,'int32')
            return;
        end
        data(:,1) = obj.x - obj.header.x_offset;
        data(:,2) = obj.y - obj.header.y_offset;
        data(:,3) = obj.z - obj.header.z_offset;
        data(:,1) = round(data(:,1) / obj.header.scale_factor_x);
        data(:,2) = round(data(:,2) / obj.header.scale_factor_y);
        data(:,3) = round(data(:,3) / obj.header.scale_factor_z);        
        data = int32(data);
    end   
       
    function x = get_x(obj)
        x = obj.x;
    end

    function y = get_y(obj)
        y = obj.y;
    end

    function z = get_z(obj)
        z = obj.z;
    end
    
    function xy = get_xy(obj)
        xy = [obj.x obj.y];
    end    

    function xyz = get_xyz(obj)
        xyz = [obj.x obj.y obj.z];
    end    
    
    
    function intensity = get_intensity(obj)
        if isempty(obj.intensity)
            obj.read_intensity();
        end         
        intensity = obj.intensity;
    end    

    function classification = get_classification(obj)
        if isempty(obj.classification)
            obj.read_classification();
        end         
        classification = obj.classification;
    end    
    
    function user_data = get_user_data(obj)
        if isempty(obj.user_data)
            obj.read_user_data();
        end         
        user_data = obj.user_data;
    end       

    function scan_angle = get_scan_angle(obj)
        if isempty(obj.scan_angle)
            obj.read_scan_angle();
        end         
        scan_angle = obj.scan_angle;
    end    
    
    function point_source_id = get_point_source_id(obj)
        if isempty(obj.point_source_id)
            obj.read_point_source_id();
        end         
        point_source_id = obj.point_source_id;
    end        

    function gps_time = get_gps_time(obj)
        if isempty(obj.gps_time)
            obj.read_gps_time();
        end         
        gps_time = obj.gps_time;
    end     

    function color = get_color(obj)
        if isempty(obj.red)
            obj.read_color();
        end
        if any(obj.header.point_data_format == [8 10])
            color = [obj.red obj.green obj.blue obj.nir];
        else
            color = [obj.red obj.green obj.blue];
        end
    end
    
    function waveXYZ = get_waveXYZ(obj)
        if isempty(obj.Xt)
            obj.read_point_wave_info();
        end
        waveXYZ = [obj.Xt obj.Yt obj.Zt];
    end

    function return_point = get_wave_return_point(obj)
        if isempty(obj.Xt)
            obj.read_point_wave_info();
        end
        return_point = obj.wave_return_point;
    end
    
    function wavedesc = get_wave_descriptor(obj)
        if isempty(obj.Xt)
            obj.read_point_wave_info();
        end
        wavedesc = obj.wavedescriptors;
    end
       
    function returns = get_return_number(obj)
        if isempty(obj.bits)
            obj.read_bits();
        end        
        if obj.header.point_data_format < 6
            returns = bitand(obj.bits,7);
        else
            returns = bitand(obj.bits,15);
        end
    end
    
    function returns = get_number_of_returns(obj)
        if isempty(obj.bits)
            obj.read_bits();
        end
        if obj.header.point_data_format < 6
            returns = bitshift(bitand(obj.bits,56),-3);
        else
            returns = bitshift(bitand(obj.bits,240),-4);
        end
    end    
    
    function returns = get_classification_flags(obj)
        if isempty(obj.bits)
            obj.read_bits();
        end        
        if obj.header.point_data_format < 6
            returns = [];
        else
            returns = bitand(obj.bits2,15);
        end
    end    
    
    function returns = get_scan_direction_flag(obj)
        if isempty(obj.bits)
            obj.read_bits();
        end        
        if obj.header.point_data_format < 6
            returns = bitand(obj.bits,64);
        else
            returns = bitand(obj.bits2,64);
        end
    end      

    function returns = get_edge_of_flight_line(obj)
        if isempty(obj.bits)
            obj.read_bits();
        end        
        if obj.header.point_data_format < 6
            returns = bitand(obj.bits,128);
        else
            returns = bitand(obj.bits2,128);
        end
    end
    
    function returns = get_scanner_channel(obj)
        if isempty(obj.bits)
            obj.read_bits();
        end        
        if obj.header.point_data_format < 6
            returns = [];
        else
            returns = bitshift(bitand(obj.bits2,48),-4);
        end
    end      
    
    function waves = getwaveforms(obj,points)
        if isempty(obj.wave_packet_descriptor)
            obj = read_point_wave_info(obj);
        end
        
        bitstrs = cell(length(obj.wavedescriptors),1);
        for k=1:length(obj.wavedescriptors)
            bitstrs{k} = ['*ubit' num2str(obj.wavedescriptors(obj.wave_packet_descriptor(k)).bits)];
        end
        
        fid = fopen(obj.waveformfile,'r'); %multithreading fix

        DATASTART = obj.header.start_of_waveform_data;
        waves = cell(length(points),1);
        for k=1:length(points)
            p = points(k);
            if fseek(fid,double(DATASTART+obj.wave_byte_offset(p)),-1)<0
                error('fseek failed');
            end
            if obj.wave_packet_descriptor(p) %if wavepacket id not zero then waveform exists
                DATAPOINTS = floor(double(obj.wave_packet_size(p))*8 / ...
                    double(obj.wavedescriptors(obj.wave_packet_descriptor(p)).bits));
                waves{k} = fread(fid,DATAPOINTS,...
                    bitstrs{obj.wave_packet_descriptor(p)});
            else
                waves{k} = [];
            end
        end
        fclose(fid);
    end
  
    function obj = setfilter(obj,varargin)
    % setfilter adds given filter command to the filter stack.
    % To reset filtering, reload the class from the original data.
    % Specify filter with setfilter('filter',value,'filter',value...)
    % or give filters sequentially obj.setfilter(...); obj.setfilter(...), 
    % however this method is slower as it causes reloading of the data.
    
        if nargin < 3 %+1 comes from the class obj
            error('Incorrect parameter count.');
        end
        
        %clear filter
        if isempty(obj.selection)
            obj.selection = true(obj.header.number_of_point_records,1); 
        end
        
        k=1;
        while k<=length(varargin)
            switch( varargin{k} )
                case 'area'
                    area = varargin{k+1};                    
                    if numel(area) ~=4
                        error('Area definition requires rectangle [x,y,width,height].')
                    end

                    %reload if data is not in the original condition
                    if isempty(obj.x) || ( length(obj.x) ~= length(obj.selection) )
                        obj.read_xyz(1);
                    end                    

                    obj.selection = obj.selection & ...
                        (obj.x >= area(1) & obj.x<= area(1)+area(3) & ...
                        obj.y >= area(2) & obj.y<= area(2)+area(4));
                    k = k+2;
                case 'classification'
                    val = varargin{k+1};                    
                    if ~isnumeric(val)
                        error('Classification comparison requires a vector input of classification codes.')
                    end                        
                    %reload if data is not in the original condition
                    if isempty(obj.classification) || ( length(obj.classification) ~= length(obj.selection) )
                        obj.read_classification(1);
                    end

                    obj.selection = obj.selection & ( ismember(obj.classification, val) );
                    k = k+2;                    
                case 'user_data'
                    val = varargin{k+1};                    
                    if numel(val) ~=1 || ~isnumeric(val)
                        error('User data comparison requires a single number.')
                    end                    
                    %reload if data is not in the original condition
                    if isempty(obj.user_data) || ( length(obj.user_data) ~= length(obj.selection) )
                        obj.read_user_data(1);
                    end

                    obj.selection = obj.selection & (obj.user_data == val);
                    k = k+2;                    
                case 'scan_angle'
                    operator = varargin{k+1};                    
                    if ~ischar(operator) && any(strncmp(operator,{'==','~=','<','>','<=','>='},2))
                        error('Comparison operator must be one of [==,~=,<,>,<=,>=].')
                    end

                    val = varargin{k+2};                    
                    if numel(val) ~=1 || ~isnumeric(val)
                        error('Scan angle comparison requires a single number.')
                    end                    
                    %reload if data is not in the original condition
                    if isempty(obj.scan_angle) || ( length(obj.scan_angle) ~= length(obj.selection) )
                        obj.read_scan_angle(1);
                    end

                    eval(['obj.selection = obj.selection & (obj.scan_angle ' operator ' val);']);
                    k = k+3;                    
                case 'custom'
                    fil = varargin{k+1};
                    
                    if length(fil) == length(obj.x)
                        idx = find(obj.selection);
                        idx = fil(:).*idx;
                        fil = false(size(obj.selection));
                        idx(idx==0) = [];
                        fil(idx) = true;
                    end
                    if numel(fil) ~=length(obj.selection) || ~islogical(fil)
                        error('Custom filter must be as long as is the length of the original or current data')
                    end                    

                    obj.selection = obj.selection & fil;    
                    k = k+2;                    
                otherwise
                    error('Unknown filtering command');
            end
        end
        
        %reload existing datas and set filter
        if length(obj.x) ~= length(obj.selection)
            obj.read_xyz(1);
        end
        obj.x = obj.x(obj.selection);
        obj.y = obj.y(obj.selection);
        obj.z = obj.z(obj.selection);        

        if ~isempty(obj.intensity) && ( length(obj.intensity) ~= length(obj.selection) )
            obj.read_intensity(1);
        end
        if ~isempty(obj.intensity)
            obj.intensity = obj.intensity(obj.selection);
        end
        
        if ~isempty(obj.classification) && ( length(obj.classification) ~= length(obj.selection) )
            obj.read_classification(1);
        end
        if ~isempty(obj.classification)
            obj.classification = obj.classification(obj.selection);
        end
        
        if ~isempty(obj.bits) && ( length(obj.bits) ~= length(obj.selection) )
            obj.read_bits(1);
        end        
        if ~isempty(obj.bits)
            obj.bits = obj.bits(obj.selection);
            if ~isempty(obj.bits2)
                obj.bits2 = obj.bits2(obj.selection);
            end
        end
        
        if ~isempty(obj.user_data) && ( length(obj.user_data) ~= length(obj.selection) )
            obj.read_user_data(1);
        end        
        if ~isempty(obj.user_data)
            obj.user_data = obj.user_data(obj.selection);
        end
      
        if ~isempty(obj.scan_angle) && ( length(obj.scan_angle) ~= length(obj.selection) )
            obj.read_scan_angle(1);
        end        
        if ~isempty(obj.scan_angle)
            obj.scan_angle = obj.scan_angle(obj.selection);
        end        

        if ~isempty(obj.point_source_id) && ( length(obj.point_source_id) ~= length(obj.selection) )
            obj.read_point_source_id(1);
        end        
        if ~isempty(obj.point_source_id)
            obj.point_source_id = obj.point_source_id(obj.selection);
        end        
        
        if ~isempty(obj.gps_time) && ( length(obj.gps_time) ~= length(obj.selection) )
            obj.read_gps_time(1);
        end        
        if ~isempty(obj.gps_time)
            obj.gps_time = obj.gps_time(obj.selection);
        end       
        
        if ~isempty(obj.red) && ( length(obj.red) ~= length(obj.selection) )
            obj.read_color(1);
        end
        if ~isempty(obj.red)
            obj.red = obj.red(obj.selection);
            obj.green = obj.green(obj.selection);
            obj.blue = obj.blue(obj.selection);
            if ~isempty(obj.nir)
                obj.nir = obj.nir(obj.selection);
            end
        end
        
        if ~isempty(obj.extradata) && ( length(obj.extradata) ~= length(obj.selection) )
            obj.read_extradata(1);
        end        
        if ~isempty(obj.extradata)
            obj.extradata = obj.extradata(obj.selection,:);
        end  

        if ~isempty(obj.Xt) && ( length(obj.Xt) ~= length(obj.selection) )
            obj.read_point_wave_info(1);
        end        
        if ~isempty(obj.Xt)
            obj.Xt = obj.Xt(obj.selection);
            obj.Yt = obj.Yt(obj.selection);
            obj.Zt = obj.Zt(obj.selection);
            obj.wave_return_point = obj.wave_return_point(obj.selection); 
            
            obj.wave_packet_descriptor = obj.wave_packet_descriptor(obj.selection);
            obj.wave_byte_offset = obj.wave_byte_offset(obj.selection);
            obj.wave_packet_size = obj.wave_packet_size(obj.selection);            
        end           
    end
    
    function obj = read_xyz(obj,donotfilter)
        fid = fopen(obj.filename);
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        OFFSET = obj.header.offset_to_point_data;      
        fseek(fid,OFFSET,-1);
        obj.x = fread(fid,POINTS,'*int32',LEN-4);  %x
        fseek(fid,OFFSET+4,-1);
        obj.y = fread(fid,POINTS,'*int32',LEN-4);  %y
        fseek(fid,OFFSET+8,-1);
        obj.z = fread(fid,POINTS,'*int32',LEN-4);  %z   
        
        fclose(fid);
        
        %apply filter
        if ~exist('donotfilter','var')
            obj.x = obj.x(obj.selection);   
            obj.y = obj.y(obj.selection);
            obj.z = obj.z(obj.selection);        
        end
        obj.normalize_xyz();
    end
    
    function obj = write_xyz(obj)
        fid = fopen(obj.header.filename,'r+');
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        
        LEN = obj.header.point_data_record_length;
        OFFSET = 0;
        
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        obj.columndatafwrite(fid,obj.toint32_xyz(),OFFSET,LEN);

        fclose(fid);
    end    
    
    function obj = read_intensity(obj,donotfilter)
        fid = fopen(obj.filename);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        OFFSET = obj.header.offset_to_point_data + 12;
        fseek(fid,OFFSET,-1);
        obj.intensity = fread(fid,POINTS,'*uint16',LEN-2);%intensity        
        
        fclose(fid);
        
        %apply filter
        if ~exist('donotfilter','var')
            obj.intensity = obj.intensity(obj.selection);         
        end
    end
    
    function obj = write_intensity(obj)
        fid = fopen(obj.header.filename,'r+');     
        LEN = obj.header.point_data_record_length;
        OFFSET = 12;
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        obj.columndatafwrite(fid,obj.intensity,OFFSET,LEN);
        fclose(fid);        
    end        
    
    function obj = read_bits(obj,donotfilter)
        fid = fopen(obj.filename);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        OFFSET = obj.header.offset_to_point_data + 14;
        
        fseek(fid,OFFSET,-1);
        obj.bits = fread(fid,POINTS,'*uint8',LEN-1);  %bits     
        
        if obj.header.version_minor > 3 && obj.header.point_data_format > 5 %1.4 && pointformat >=6
            fseek(fid,OFFSET+1,-1);
            obj.bits2 = fread(fid,POINTS,'*uint8',LEN-1);  %bits2              
        end
        
        fclose(fid);
        
        %apply filter
        if ~exist('donotfilter','var')
            obj.bits = obj.bits(obj.selection); 
            if ~isempty(obj.bits2)
                obj.bits2 = obj.bits2(obj.selection); 
            end
        end
    end    
    
    function obj = write_bits(obj)
        fid = fopen(obj.header.filename,'r+');     
        LEN = obj.header.point_data_record_length;
        OFFSET = 14;
        
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        obj.columndatafwrite(fid,obj.bits,OFFSET,LEN);           
        
        if obj.header.version_minor > 3 && obj.header.point_data_format > 5 %1.4 & pointformat >=6
            fseek(fid,double(obj.header.offset_to_point_data),-1);
            obj.columndatafwrite(fid,obj.bits2,OFFSET+1,LEN);               
        end
        fclose(fid);        
    end    
    
    function obj = read_classification(obj,donotfilter)
        fid = fopen(obj.filename);
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        
        offsettable = [15 15 15 15 15 15 16 16 16 16 16]; 
        
        OFFSET = offsettable(obj.header.point_data_format+1)+obj.header.offset_to_point_data;  
        
        fseek(fid,OFFSET,-1);
        obj.classification= fread(fid,POINTS,'*uint8',LEN-1);    
        
        fclose(fid);

        %apply filter
        if ~exist('donotfilter','var')        
            obj.classification = obj.classification(obj.selection);           
        end
    end    

    function obj = write_classification(obj)
        fid = fopen(obj.header.filename,'r+');     
        
        LEN = obj.header.point_data_record_length;
        offsettable = [15 15 15 15 15 15 16 16 16 16 16]; 
        OFFSET = offsettable(obj.header.point_data_format+1);

        fseek(fid,double(obj.header.offset_to_point_data),-1);
        obj.columndatafwrite(fid,obj.classification,OFFSET,LEN);  
        fclose(fid);        
    end    
    
    function obj = read_scan_angle(obj,donotfilter)
        fid = fopen(obj.filename);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        
        offsettable = [16 16 16 16 16 16 18 18 18 18 18];
        datatypetable = {'*int8', '*int8', '*int8', '*int8', '*int8', ...
            '*int8', '*int16', '*int16', '*int16', '*int16', '*int16'}; 
        datasizetable = [1 1 1 1 1 1 2 2 2 2 2];
        
        OFFSET = offsettable(obj.header.point_data_format+1)+obj.header.offset_to_point_data;  
        DATATYPE = datatypetable{obj.header.point_data_format+1};
        DATASIZE = datasizetable(obj.header.point_data_format+1);
        
        fseek(fid,OFFSET,-1);
        obj.scan_angle= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        
        fclose(fid);

        %apply filter
        if ~exist('donotfilter','var')        
            obj.scan_angle = obj.scan_angle(obj.selection);          
        end
    end      

    function obj = write_scan_angle(obj)
        fid = fopen(obj.header.filename,'r+');     
        LEN = obj.header.point_data_record_length;
       
        offsettable = [16 16 16 16 16 16 18 18 18 18 18];
        OFFSET = offsettable(obj.header.point_data_format+1);
        datatypetable = {'int8', 'int8', 'int8', 'int8', 'int8', ...
            'int8', 'int16', 'int16', 'int16', 'int16', 'int16'}; 
        
        DATATYPE = datatypetable{obj.header.point_data_format+1};
        
        if ~isa(obj.scan_angle,DATATYPE)
            error(['Scan angle datatype is not: ' DATATYPE])
        end
        
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        obj.columndatafwrite(fid,obj.scan_angle,OFFSET,LEN);   
        fclose(fid);        
    end      
    
    function obj = read_user_data(obj,donotfilter)
        fid = fopen(obj.filename);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        
        offsettable = [17 17 17 17 17 17 17 17 17 17 17];
        OFFSET = offsettable(obj.header.point_data_format+1);
        DATATYPE ='*uint8';
        DATASIZE = 1;
        
        fseek(fid,OFFSET,-1);
        obj.user_data= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        
        fclose(fid);
        
        %apply filter
        if ~exist('donotfilter','var')        
            obj.user_data = obj.user_data(obj.selection);          
        end
    end      
    
    function obj = write_user_data(obj)
        fid = fopen(obj.header.filename,'r+');     
        LEN = obj.header.point_data_record_length;
        DATATYPE ='uint8';
        offsettable = [17 17 17 17 17 17 17 17 17 17 17];
        OFFSET = offsettable(obj.header.point_data_format+1);
        
        if ~isa(obj.user_data,DATATYPE)
            error(['User data datatype is not: ' DATATYPE])
        end
        
        fseek(fid,double(obj.header.offset_to_point_data),-1);

        obj.columndatafwrite(fid,obj.user_data,OFFSET,LEN);  
        fclose(fid);        
    end      
    
    function obj = read_point_source_id(obj,donotfilter)
        fid = fopen(obj.filename);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        
        offsettable = [18 18 18 18 18 18 20 20 20 20 20];
        
        OFFSET = offsettable(obj.header.point_data_format+1)+obj.header.offset_to_point_data;  
        DATATYPE = '*uint16';
        DATASIZE = 2;
        
        fseek(fid,OFFSET,-1);
        obj.point_source_id= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        
        fclose(fid);

        %apply filter
        if ~exist('donotfilter','var')        
            obj.point_source_id = obj.point_source_id(obj.selection);         
        end
    end

    function obj = write_point_source_id(obj)
        fid = fopen(obj.header.filename,'r+');     
        LEN = obj.header.point_data_record_length;
        offsettable = [18 18 18 18 18 18 20 20 20 20 20];
        OFFSET = offsettable(obj.header.point_data_format+1);
        DATATYPE = 'uint16';
        
        if ~isa(obj.point_source_id,DATATYPE)
            error(['Point source id datatype is not: ' DATATYPE])
        end
        
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        obj.columndatafwrite(fid,obj.point_source_id,OFFSET,LEN);  
        fclose(fid);        
    end        
    
    function obj = read_gps_time(obj,donotfilter)
        %check if not in this point format
        if any(obj.header.point_data_format == [0 2]) 
            return;
        end
        
        fid = fopen(obj.filename);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        
        offsettable = [20 20 20 20 20 20 22 22 22 22 22];
        
        OFFSET = offsettable(obj.header.point_data_format+1)+obj.header.offset_to_point_data;  
        DATATYPE = '*double';
        DATASIZE = 8;
        
        fseek(fid,OFFSET,-1);
        obj.gps_time= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        
        fclose(fid);
        
        %apply filter
        if ~exist('donotfilter','var')        
            obj.gps_time = obj.gps_time(obj.selection);             
        end
    end     
    

    function obj = write_gps_time(obj)
        fid = fopen(obj.header.filename,'r+');     
        %check if not in this point format
        if any(obj.header.point_data_format == [0 2]) 
            return;
        end

        LEN = obj.header.point_data_record_length;
        offsettable = [20 20 20 20 20 20 22 22 22 22 22];
        OFFSET = offsettable(obj.header.point_data_format+1);
        DATATYPE = 'double';

        if ~isa(obj.gps_time,DATATYPE)
            error(['GPS time datatype is not: ' DATATYPE])
        end        
   
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        obj.columndatafwrite(fid,obj.gps_time,OFFSET,LEN); 
        fclose(fid);        
    end         
    
    function obj = read_color(obj,donotfilter)
        %check if not in this point format
        if any(obj.header.point_data_format == [0 1 2 4 6 9]) 
            return;
        end
        
        fid = fopen(obj.filename);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        
        offsettable = [20 20 20 28 28 28 30 30 30 30 30];
        
        OFFSET = offsettable(obj.header.point_data_format+1)+obj.header.offset_to_point_data;  
        DATATYPE = '*uint16';
        DATASIZE = 2;
        
        fseek(fid,OFFSET,-1);
        obj.red= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        fseek(fid,OFFSET+2,-1);
        obj.green= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        fseek(fid,OFFSET+4,-1);
        obj.blue= fread(fid,POINTS,DATATYPE,LEN-DATASIZE); 
        if any(obj.header.point_data_format == [8 10])
            fseek(fid,OFFSET+6,-1);
            obj.nir= fread(fid,POINTS,DATATYPE,LEN-DATASIZE); 
        end
        
        fclose(fid);
        
        %apply filter
        if ~exist('donotfilter','var')        
            obj.red = obj.red(obj.selection);     
            obj.green = obj.green(obj.selection);  
            obj.blue = obj.blue(obj.selection);          
            if ~isempty(obj.nir)
                obj.nir = obj.nir(obj.selection);          
            end
        end
    end     
    
    function obj = write_color(obj)
        fid = fopen(obj.header.filename,'r+');     
        %check if not in this point format
        if any(obj.header.point_data_format == [0 1 2 4 6 9]) 
            return;
        end
        
        LEN = obj.header.point_data_record_length;
        offsettable = [20 20 20 28 28 28 30 30 30 30 30];
        OFFSET = offsettable(obj.header.point_data_format+1);
        DATATYPE = 'uint16';

        if ~isa(obj.red,DATATYPE)
            error(['Color datatype is not: ' DATATYPE])
        end              
        
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        obj.columndatafwrite(fid,[obj.red obj.green obj.blue],OFFSET,LEN);    
        
        if any(obj.header.point_data_format == [8 10])        
            fseek(fid,double(obj.header.offset_to_point_data),-1);
            obj.columndatafwrite(fid,obj.nir,OFFSET+6,LEN);    
        end
        
        fclose(fid);
    end         
    
    function obj = read_point_wave_info(obj,donotfilter)
        %check if not in this point format
        if any(obj.header.point_data_format == [0 1 2 3 6 7 8]) 
            return;
        end
        
        fid = fopen(obj.filename);
        
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        
        offsettable = [28 28 28 28 28 28 28 28 28 30 38];
        
        OFFSET = offsettable(obj.header.point_data_format+1)+obj.header.offset_to_point_data;  
        DATATYPE = '*uint8';
        DATASIZE = 1;
        
        fseek(fid,OFFSET,-1);
        obj.wave_packet_descriptor= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    

        DATATYPE = '*uint64';
        DATASIZE = 8;
        fseek(fid,OFFSET+1,-1);
        obj.wave_byte_offset= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    

        DATATYPE = '*uint32';
        DATASIZE = 4;
        fseek(fid,OFFSET+9,-1);
        obj.wave_packet_size= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        
        DATATYPE = '*single';
        DATASIZE = 4;
        fseek(fid,OFFSET+13,-1);
        obj.wave_return_point= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        
        DATATYPE = '*single';
        DATASIZE = 4;
        fseek(fid,OFFSET+17,-1);
        obj.Xt= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    

        DATATYPE = '*single';
        DATASIZE = 4;
        fseek(fid,OFFSET+21,-1);
        obj.Yt= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    

        DATATYPE = '*single';
        DATASIZE = 4;
        fseek(fid,OFFSET+25,-1);
        obj.Zt= fread(fid,POINTS,DATATYPE,LEN-DATASIZE);    
        
        fclose(fid);
        
        %apply filter
        if ~exist('donotfilter','var')        
            obj.wave_packet_descriptor = obj.wave_packet_descriptor(obj.selection);
            obj.wave_byte_offset = obj.wave_byte_offset(obj.selection);
            obj.wave_packet_size = obj.wave_packet_size(obj.selection);
            obj.wave_return_point = obj.wave_return_point(obj.selection);
            obj.Xt = obj.Xt(obj.selection);
            obj.Yt = obj.Yt(obj.selection);
            obj.Zt = obj.Zt(obj.selection);
        end         
    end

    function obj = write_point_wave_info(obj)
        fid = fopen(obj.header.filename,'r+');
        %check if not in this point format
        if any(obj.header.point_data_format == [0 1 2 3 6 7 8])
            return;
        end
       
        LEN = obj.header.point_data_record_length;
        
        offsettable = [28 28 28 28 28 28 28 28 28 30 38];
        
        DATATYPE = 'uint8';
        if ~isa(obj.wave_packet_descriptor,DATATYPE)
            error(['Wave packet descriptor datatype is not: ' DATATYPE])
        end              
        
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        OFFSET = offsettable(obj.header.point_data_format+1);
        obj.columndatafwrite(fid,obj.wave_packet_descriptor,OFFSET,LEN);  
                
        DATATYPE = 'uint64';
        if ~isa(obj.wave_byte_offset,DATATYPE)
            error(['Wave byte offset datatype is not: ' DATATYPE])
        end
        
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        OFFSET = offsettable(obj.header.point_data_format+1)+1;
        obj.columndatafwrite(fid,obj.wave_byte_offset,OFFSET,LEN);  

        DATATYPE = 'uint32';
        if ~isa(obj.wave_packet_size,DATATYPE)
            error(['Wave packet size datatype is not: ' DATATYPE])
        end              
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        OFFSET = offsettable(obj.header.point_data_format+1)+9;
        obj.columndatafwrite(fid,obj.wave_packet_size,OFFSET,LEN);  
        
        DATATYPE = 'single';
        if ~isa(obj.wave_return_point,DATATYPE)
            error(['Wave return point datatype is not: ' DATATYPE])
        end             
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        OFFSET = offsettable(obj.header.point_data_format+1)+13;
        obj.columndatafwrite(fid,obj.wave_return_point,OFFSET,LEN);  
        
        DATATYPE = 'single';
        if ~isa(obj.Xt,DATATYPE)
            error(['Xt datatype is not: ' DATATYPE])
        end    
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        OFFSET = offsettable(obj.header.point_data_format+1)+17;
        obj.columndatafwrite(fid,obj.Xt,OFFSET,LEN);          

        DATATYPE = 'single';
        if ~isa(obj.Yt,DATATYPE)
            error(['Yt datatype is not: ' DATATYPE])
        end      
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        OFFSET = offsettable(obj.header.point_data_format+1)+21;
        obj.columndatafwrite(fid,obj.Yt,OFFSET,LEN);          

        DATATYPE = 'single';
        if ~isa(obj.Zt,DATATYPE)
            error(['Zt datatype is not: ' DATATYPE])
        end    
        fseek(fid,double(obj.header.offset_to_point_data),-1);
        OFFSET = offsettable(obj.header.point_data_format+1)+25;
        obj.columndatafwrite(fid,obj.Zt,OFFSET,LEN);   
        fclose(fid);        
    end         
    
    function obj = read_extradata(obj)
        LEN = obj.header.point_data_record_length;
        POINTS = obj.header.number_of_point_records;
        
        offsettable = [20 28 26 34 57 63 30 36 38 59 67]; %magic numbers from point record byte lengths
        OFFSET = offsettable(obj.header.point_data_format+1)+obj.header.offset_to_point_data;        
        
        extralen = obj.header.point_data_record_length - offsettable(obj.header.point_data_format+1);
        if extralen>0 %unknown extra data exists
            fid = fopen(obj.filename);
 
            fseek(fid,OFFSET,-1);
            obj.extradata = zeros(POINTS,extralen,'uint8');
            for k=1:POINTS
                obj.extradata(k,:) = fread(fid,extralen,'*uint8');
                fseek(fid,LEN-extralen,0);
            end          
            
            fclose(fid);
        end
        
        %apply filter
        if ~exist('donotfilter','var') && ~isempty(obj.extradata)
            obj.extradata = obj.extradata(obj.selection,:);
        end
    end


    function obj = write_extradata(obj)
        fid = fopen(obj.header.filename,'r+');     
        LEN = obj.header.point_data_record_length;
        offsettable = [20 28 26 34 57 63 30 36 38 59 67]; %magic numbers from point record byte lengths
        OFFSET = offsettable(obj.header.point_data_format+1);        
        
        extralen = size(obj.extradata,2);
        if extralen %unknown extra data exists
            if ~isa(obj.extradata,'uint8')
                error(['Row extra data datatype is not: uint8'])
            end     
                        
            fseek(fid,double(obj.header.offset_to_point_data),-1);
            obj.columndatafwrite(fid,obj.extradata,OFFSET,LEN);            
        end
        fclose(fid);        
    end    
    
    function plot_xyz(obj,pointlimit)
        if ~exist('pointlimit','var')
            pointlimit = 10000;
        end
        if pointlimit == -1
            pointlimit = length(obj.x);
        end
        if isempty(obj.x)
            warning('No points to plot, check filtering!') 
            return;
        end
        sel = randi(length(obj.x),pointlimit,1);
        set(gcf,'renderer','opengl')
        obj.get_intensity();
        scatter3(obj.x(sel),obj.y(sel),obj.z(sel),100,obj.intensity(sel),'r.')
    end
    
    function plot_intensity(obj,pointlimit)
        if ~exist('pointlimit','var')
            pointlimit = 10000;
        end
        if pointlimit == -1
            pointlimit = length(obj.x);
        end
        if isempty(obj.x)
            warning('No points to plot, check filtering!') 
            return;
        end
        
        sel = randi(length(obj.x),pointlimit,1);
        set(gcf,'renderer','opengl')
        obj.get_intensity();
        scatter3(obj.x(sel),obj.y(sel),obj.z(sel),100,obj.intensity(sel),'.')
    end

    function plot_classification(obj,pointlimit,no_z)
        if ~exist('pointlimit','var')
            pointlimit = 10000;
        end
        if pointlimit == -1
            pointlimit = length(obj.x);
        end
        if isempty(obj.x)
            warning('No points to plot, check filtering!') 
            return;
        end
        
        sel = randi(length(obj.x),pointlimit,1);
        set(gcf,'renderer','opengl')
        obj.get_classification();
        if ~exist('no_z','var')
            scatter(obj.x(sel),obj.y(sel),100,obj.classification(sel),'.')
        else
            scatter3(obj.x(sel),obj.y(sel),obj.z(sel),100,obj.classification(sel),'.')
        end
    end
    
    function plot_waveforms(obj,pointlimit,alphaon)
        if ~exist('pointlimit','var')
            pointlimit = 1000;
        end
        if pointlimit == -1
            pointlimit = length(obj.x);
        end
        if isempty(obj.x)
            warning('No points to plot, check filtering!') 
            return;
        end
        
        
        %select last returns
        subset = find(obj.get_return_number() == obj.get_number_of_returns());
        %and random amount of these points or all
        subset = subset(randi(size(subset,1),pointlimit,1));
        xyz = obj.get_xyz();
        
        %remove points with no waves
        waves = obj.getwaveforms(subset);
        xyz = xyz(subset,:);
        
        amplitudemax = double(max(cellfun(@max,waves)));
        firstpeaks = zeros(length(waves),1);
        for k=1:length(waves)
            [~,firstpeaks(k)] = findpeaks(double(waves{k}),'npeaks',1,'minpeakheight',mean(waves{k}));
        end
        
        %temporal spacing from descriptor (*1000000 scaling)
        step = double([obj.wavedescriptors(obj.wave_packet_descriptor(subset)).temporal_sample_spacing])*1000000;
        samples = double([obj.wavedescriptors(obj.wave_packet_descriptor(subset)).number_of_samples]);
        %calculate height of the waveform
        waveheight = (298925574./step(:)).*samples(:)/2;
        wavegroundoffset = (298925574./step(:)).*firstpeaks(:)/2;
        
        
        set(gcf,'renderer','opengl')
        hold on
        colors = jet(amplitudemax+1);
        
        %generate ground
        tri = delaunay(xyz(:,1),xyz(:,2));
        trisurf(tri,xyz(:,1),xyz(:,2),xyz(:,3),'edgecolor','none')
        
        faces = [];
        vertices = [];
        col = [];
        valpha = [];
        len = 0;
        for k=1:length(subset)
            tmpx = linspace(xyz(k,1),xyz(k,1),samples(k))'+double(waves{k})/amplitudemax/2;
            tmpy = linspace(xyz(k,2),xyz(k,2),samples(k))';
            tmpz = linspace(xyz(k,3)-wavegroundoffset(k),...
                            xyz(k,3)+waveheight(k)-wavegroundoffset(k),samples(k))';
            tmpc = colors(double(waves{k})+1,:);
            
            p = [tmpx tmpy tmpz];
            
            fc = [(1:size(p,1)-1)' (1:size(p,1)-1)' (2:size(p,1))']+ len;
            
            len = len + size(p,1);
            
            faces = [faces; fc];
            vertices = [vertices; p];
            col = [col; tmpc];
            valpha = [valpha; double(waves{k})/amplitudemax];
        end
        
        if exist('alphaon','var')
            valpha = log(valpha);
            valpha = valpha -(min(valpha));
            valpha = valpha / max(valpha);
            patch( 'Vertices', vertices, 'Faces', faces,'FaceColor','none',...
                   'EdgeColor',[0 0 0],...
                   'FaceVertexAlphaData', valpha,...
                   'EdgeAlpha','interp','AlphaDataMapping','none');        
        else
            patch( 'Vertices', vertices, 'Faces', faces,'FaceColor','none',...
                   'FaceVertexCData',col,'EdgeColor','interp');        
        end
    end    
    

    function plot_waveform_layers(obj)
        
        if isempty(obj.x)
            warning('No points to plot, check filtering!') 
            return;
        end       
        
        %select last returns
        subset = find(obj.get_return_number() == obj.get_number_of_returns());
        xyz = obj.get_xyz();
        xyz = xyz(subset,:);
        
        xlimorg = [min(xyz(:,1)) max(xyz(:,1))];
        ylimorg = [min(xyz(:,2)) max(xyz(:,2))];
        ZADD = 30;
        zlimorg = [min(xyz(:,3)) max(xyz(:,3))+ZADD];        
        
        xyz(:,1) = xyz(:,1)-min(xyz(:,1));
        xyz(:,2) = xyz(:,2)-min(xyz(:,2));
        xyz(:,3) = xyz(:,3)-min(xyz(:,3));
        
        waves = obj.getwaveforms(subset);
        removeempty = cellfun(@isempty,waves);
        subset = subset(~removeempty);
        xyz = xyz(~removeempty,:);
        waves = waves(~removeempty);
        
        %create voxel structure
        NX = 256; NY = 256; NZ = 256;
        layers = zeros(NX,NY,NZ,'uint8');
        xlim = [min(xyz(:,1)) max(xyz(:,1))];
        ylim = [min(xyz(:,2)) max(xyz(:,2))];
        zlim = [min(xyz(:,3)) max(xyz(:,3))+ZADD];
                
        amplitudemax = double(max(cellfun(@max,waves)));
        firstpeaks = zeros(1,length(waves));
        for k=1:length(waves)
            [~,firstpeaks(k)] = findpeaks(double(waves{k}),'npeaks',1,'minpeakheight',mean(waves{k}));
        end
        
        %temporal spacing from descriptor (*1000000 scaling)
        step = double([obj.wavedescriptors(obj.wave_packet_descriptor(subset)).temporal_sample_spacing])*1000000;
        samples = double([obj.wavedescriptors(obj.wave_packet_descriptor(subset)).number_of_samples]);
        %calculate height of the waveform
        waveheight = (298925574./step).*samples/2;
        wavegroundoffset = (298925574./step).*firstpeaks/2;
        
        set(gcf,'renderer','opengl')
        hold on
        
        for k=1:length(subset)
            tmpx = linspace(xyz(k,1),xyz(k,1),samples(k))';
            tmpy = linspace(xyz(k,2),xyz(k,2),samples(k))';
            tmpz = linspace(xyz(k,3)-wavegroundoffset(k),...
                            xyz(k,3)+waveheight(k)-wavegroundoffset(k),samples(k))';
            amp = (double(waves{k})/amplitudemax)*255;
            
            px = floor((tmpx)/(xlim(2))*(NX-1))+1;
            py = floor((tmpy)/(ylim(2))*(NY-1))+1;
            pz = floor((tmpz)/(zlim(2))*(NZ-1))+1;
            
            for r=1:length(px)
                if pz(r)<=NZ && pz(r)>0 && layers(px(r),py(r),pz(r)) < amp(r)
                    layers(px(r),py(r),pz(r)) = amp(r); 
                end
            end
        end
        
        alim([0 255]);
        for k = 1:NZ
            zk = zlimorg(1)+(zlimorg(2)-zlimorg(1))/NZ*(k-1);
            surf([xlimorg(1) xlimorg(2); xlimorg(1) xlimorg(2)],...
                [ylimorg(1) ylimorg(1); ylimorg(2) ylimorg(2)],...
                [zk zk; zk zk],'CData',layers(:,:,k),'FaceColor','texturemap',...
                'EdgeColor','none','FaceAlpha', 'texturemap', ...
                'AlphaDataMapping', 'scaled', 'AlphaData',layers(:,:,k));        
        end
    end        
    
    function obj = write_las(obj, filename, majorversion, minorversion, pointformat)
        
        %prevent overwriting
        %if you like to overwrite files, then read all variables to memory 
        %at this point and disable check
        [pathtmp,filetmp,ext]=fileparts(obj.filename);
        if isempty(pathtmp); pathtmp = pwd; end
        orgfile = [pathtmp '/' filetmp ext];
        [pathtmp,filetmp]=fileparts(filename);
        if isempty(pathtmp); pathtmp = pwd; end
        newfile = [pathtmp '/' filetmp ext];    
        
        if strcmpi(orgfile,newfile)
            error('Overwriting is not allowed.')
        end
        
        newheader = obj.header;
        oldheader = obj.header;
        if ~exist('filename','var')
            error('Please input target filename.')
        end
        if exist('majorvarsion','var')
            newheader.version_major = majorversion;
        end
        if exist('minorversion','var')
            newheader.version_minor = minorversion;
        end
        if exist('pointformat','var')
            newheader.point_data_format = pointformat;
        end
        newheader.number_of_point_records = length(obj.x);
        newheader.max_x = max(obj.x);
        newheader.min_x = min(obj.x);
        newheader.max_y = max(obj.y);
        newheader.min_y = min(obj.y);
        newheader.max_z = max(obj.z);
        newheader.min_z = min(obj.z);
        newheader.filename = filename;

        fid = fopen(filename,'w');        
        try 
            obj.header = newheader;
            obj.writeheader(fid);
        catch err
            obj.header = oldheader;
            error(['Error writing las header: ' err.getReport]);
        end
        obj.header = oldheader;
        
        LEN = length(obj.x);
        if isempty(obj.intensity)
            obj.read_intensity();
            if isempty(obj.intensity)
                warning('Adding zeros to intensity')                
                obj.intensity = zeros(LEN,1,'uint16');
            end
        end
        if isempty(obj.bits)
            obj.read_bits();
            if isempty(obj.bits)
                warning('Adding zeros to bit values (return nr, scan dir. flag, edge of flight line)')                
                obj.bits = zeros(LEN,1,'uint8');
            end
        end

        if any(newheader.point_data_format == [6 7 8 9 10])
            if isempty(obj.bits2)
                obj.bits2 = zeros(LEN,1,'uint8');
            end
            %convert to new point formats
            if oldheader.point_data_format < 6
                obj.bits = bitor(obj.get_return_number, bitshift(obj.get_number_of_returns,4));
                obj.bits2 = bitor(bitshift(obj.get_scan_direction_flag,6), bitshift(obj.get_edge_of_flight_line,7));
            end
        end
        if any(oldheader.point_data_format > 5) && newheader.point_data_format < 6
            %convert to old point formats
            if oldheader.point_data_format > 5
                obj.bits = bitor(bitand(obj.get_return_number,7), bitand(bitshift(obj.get_number_of_returns,3),7));
                obj.bits = bitor(obj.bits, bitor(bitshift(obj.get_scan_direction_flag,6), bitshift(obj.get_edge_of_flight_line,7)));
            end                
        end        
            
        if isempty(obj.classification)
            obj.read_classification();
            if isempty(obj.classification)
                warning('Adding zeros to classification')                
                obj.classification = zeros(LEN,1,'uint8');
            end
        end        
        
        if isempty(obj.scan_angle)
            obj.read_scan_angle();
            if isempty(obj.scan_angle)
                warning('Adding zeros to scan angle')                
                obj.scan_angle = zeros(LEN,1,'uint8');
            end
        end   
        
        if isempty(obj.user_data)
            obj.read_user_data();
            if isempty(obj.user_data)
                warning('Adding zeros to user data')
                obj.user_data = zeros(LEN,1,'uint8');
            end
        end    
        
        if isempty(obj.point_source_id)
            obj.read_point_source_id();
            if isempty(obj.point_source_id)
                warning('Adding zeros to point source id')
                obj.point_source_id = zeros(LEN,1,'uint16');
            end
        end
        
        if ~any(newheader.point_data_format == [0 2]) 
            if isempty(obj.gps_time)
                obj.read_gps_time();
                if isempty(obj.gps_time)
                    warning('Adding zeros to gps time')
                    obj.gps_time = zeros(LEN,1,'double');
                end
            end            
        end
        
        if any(newheader.point_data_format == [3 5 7 8 10])
            if isempty(obj.red)
                obj.read_color();
                if isempty(obj.red)
                    warning('Adding zeros to RGB color')
                    obj.red = zeros(LEN,1,'uint16');
                    obj.green = zeros(LEN,1,'uint16');
                    obj.blue = zeros(LEN,1,'uint16');
                end
                if any(newheader.point_data_format == [8 10])
                    if isempty(obj.nir)
                        warning('Adding zeros to nir color')
                        obj.nir = zeros(LEN,1,'uint16');
                    end
                end                
            end
        end    
        
        if any(newheader.point_data_format == [4 5 9 10])
            if isempty(obj.wave_return_point)
                obj.read_point_wave_info();
                if isempty(obj.wave_return_point)
                    warning('Adding zeros to wave packet info')
                    obj.wave_packet_descriptor = zeros(LEN,1,'uint8');
                    obj.wave_byte_offset = zeros(LEN,1,'uint64');
                    obj.wave_packet_size = zeros(LEN,1,'uint32');
                    obj.wave_return_point = zeros(LEN,1,'single');
                    obj.Xt = zeros(LEN,1,'single');
                    obj.Yt = zeros(LEN,1,'single');
                    obj.Zt = zeros(LEN,1,'single');              
                end
            end
        end            
        
        obj.header = newheader;
        
        %%% variable length records
        try
            obj.write_variable_records(fid);
        catch err
            error(['Error writing variable length records: ' err.getReport]);
        end
        
        if obj.header.version_major==1 && obj.header.version_minor == 0
            tmp = char([hex2dec('DD') hex2dec('CC')]); %write las 1.0 variable record start
            fwrite(fid,tmp,'uint8');
        end
        
        %find offset to point data and write it to header in file
        tmppos = ftell(fid);
        obj.header.offset_to_point_data = tmppos;
        fseek(fid,96,-1);
        fwrite(fid,uint32(tmppos),'uint32');
        fseek(fid,tmppos,-1);        
        
        %calculate point record length and write it to header in file
        record_lengths = [20 28 26 34 57 63 30 36 38 59 67 ];
        obj.header.point_data_record_length = ...
            record_lengths(obj.header.point_data_format+1) + size(obj.extradata,2);
        fseek(fid,105,-1);
        fwrite(fid,obj.header.point_data_record_length,'uint16');
        
        %update extendedvariable offset
        if newheader.version_minor > 3 %1.4
            obj.header.start_of_extended_variable_length_record = ...
                obj.header.offset_to_point_data + length(obj.x)*obj.header.point_data_record_length;
            fseek(fid,235,-1);
            fwrite(fid,obj.header.start_of_extended_variable_length_record,'uint64');            
        end          
        
        fclose(fid);
        
        try 
            obj.write_xyz();
            obj.write_intensity();
            obj.write_bits();
            obj.write_classification();
            obj.write_scan_angle();
            obj.write_user_data();
            obj.write_point_source_id();
            obj.write_gps_time();
            obj.write_color();
            obj.write_point_wave_info();
            obj.write_extradata();            
        catch err
            error(['Error writing point data: ' err.getReport]);
        end
        
        fid = fopen(filename,'r+');
        fseek(fid,double(obj.header.offset_to_point_data+length(obj.x)*obj.header.point_data_record_length),-1);
        
        try
            obj.write_extended_variables(fid);
        catch err
            error(['Error writing extended variable data: ' err.getReport]);
        end
        
        fclose(fid);
        obj.header = oldheader;
        
    end
    

    function add_waveform_packet_desc(obj,bits,compression,numberofsamples,samplespacing,gain,offset)
        obj.header.number_of_variable_records = obj.header.number_of_variable_records + 1;
        idx = obj.header.number_of_variable_records;
        obj.variablerecords(idx).reserved = uint16(0);
        tmp = 'LASF_Spec';
        obj.variablerecords(idx).user_id = [tmp zeros(1,16-length(tmp),'uint8')];
        %calculate new descriptor number
        if ~isempty(obj.wavedescriptors)
            tmp =  [obj.variablerecords.record_id];
            tmp(tmp<100 | tmp >355) = []; %remove non wavedescriptors
            val = max(tmp);
            obj.variablerecords(idx).record_id = uint16(val+1);
        else
            obj.variablerecords(idx).record_id = uint16(100); %first id
        end
        obj.variablerecords(idx).record_length = uint16(26);
        tmp = 'Waveform Packet Descriptor';
        obj.variablerecords(idx).description = [tmp zeros(1,32-length(tmp),'uint8')];        
                
        data(1) = uint8(bits);
        data(2) = uint8(compression);
        data(3:6) = typecast(uint32(numberofsamples),'uint8');
        data(7:10) = typecast(uint32(samplespacing),'uint8');
        data(11:18) = typecast(double(gain),'uint8');
        data(19:26) = typecast(double(offset),'uint8');
        
        obj.variablerecords(idx).data = data;
        obj.wavedescriptors = obj.decode_waveform_packet_desc(obj.variablerecords);
    end
    
    function add_waveforms_to_external_file(obj,pointids,descriptorids,waves,xts,yts,zts,returnpoints)
        
        if size(waves,2)==1
            error('Input wavedatas as rows.')
        end
        
        if obj.waveformfilefid < 3
            [pathtmp,filetmp]=fileparts(obj.filename);
            if isempty(pathtmp)
                pathtmp = pwd;
            end
            obj.waveformfile = [pathtmp '\\' filetmp '.wdp'];
            obj.waveformfilefid = fopen(obj.waveformfile,'a+');
        end
        fseek(obj.waveformfilefid,0,'eof');
        
        %set external waveform file to global encoding
        obj.header.global_encoding = bitor(bitand(uint16(obj.header.global_encoding),uint16(65533)) , bitshift(uint16(1),2));
        
        %load existing data if not loaded, or data is empty
        if isempty(obj.Xt) || isempty(obj.Yt) || isempty(obj.Zt) || ...
                isempty(obj.wave_return_point) || isempty(obj.wave_packet_descriptor)...
                || isempty(obj.wave_byte_offset) || isempty(obj.wave_packet_size)
            obj.read_point_wave_info();
        end
        if size(obj.Xt) ~= size(obj.x); obj.Xt = zeros(size(obj.x),'single'); end
        if size(obj.Yt) ~= size(obj.x); obj.Yt = zeros(size(obj.x),'single'); end
        if size(obj.Zt) ~= size(obj.x); obj.Zt = zeros(size(obj.x),'single'); end
        if size(obj.wave_return_point) ~= size(obj.x); obj.wave_return_point = zeros(size(obj.x),'single'); end
        if size(obj.wave_packet_descriptor) ~= size(obj.x); obj.wave_packet_descriptor = zeros(size(obj.x),'uint8'); end
        if size(obj.wave_byte_offset) ~= size(obj.x); obj.wave_byte_offset = zeros(size(obj.x),'uint64'); end
        if size(obj.wave_packet_size) ~= size(obj.x); obj.wave_packet_size = zeros(size(obj.x),'uint32'); end
        
        obj.Xt(pointids) = xts;
        obj.Yt(pointids) = yts;
        obj.Zt(pointids) = zts;
        obj.wave_return_point(pointids) = returnpoints;
        obj.wave_packet_descriptor(pointids) = descriptorids;
        
        %multiple points with same wave 
        if size(waves,1)~= length(pointids)
            pos = ftell(obj.waveformfilefid);
            len = size(waves,2);
            obj.wave_byte_offset(pointids) = pos;
            obj.wave_packet_size(pointids) = len;
            fwrite(obj.waveformfilefid,waves,'uint8');
        else
            %insert multiple points with different waves
            for k=1:length(pointids)
                pos = ftell(obj.waveformfilefid);
                len = size(waves,2);
                obj.wave_byte_offset(pointids(k)) = pos;
                obj.wave_packet_size(pointids(k)) = len;
                fwrite(obj.waveformfilefid,waves,'uint8');
            end
        end
    end
    
end
    
methods (Access=private)    
    
    function obj = las_read( obj, file )
        if ~exist(file,'file')
            error('File not found.')
        end
        fid = fopen(file,'r');

        obj = readheader(obj,fid);

        obj.isLAZ  = 0;
        
        %check for LAZ compressed file
        if any(obj.header.point_data_format >=127) %127 laz shift on pointformat?
            obj.isLAZ  = 1;
            fclose(fid);
            if ~exist('laszip.exe','file')
                error('Cannot decompress LAZ file without laszip.exe')
            end
            obj.filename = [file '_tmp.las'];            
            system(['laszip -i ' file ' -o ' obj.filename]);
            
            fid = fopen(obj.filename,'r');

            obj = readheader(obj,fid);
        end
        
        %set filter off
        obj.selection = true(obj.header.number_of_point_records,1);        

        obj = read_variable_records(obj,fid);

        if obj.header.version_major == 1 && obj.header.version_minor == 0
            check = fread(fid,2,'uint8');  
            if check(1) ~= hex2dec('DD') && check(2) ~= hex2dec('CC')
                warning('File position do not match offset to the point data, continuing reading using header position.')
                fseek(fid,double(obj.header.offset_to_point_data),-1);                
            end
        end
        if ftell(fid) ~= obj.header.offset_to_point_data
            [ftell(fid) obj.header.offset_to_point_data]
            warning('File position do not match offset to the point data, continuing reading using header position.')
            fseek(fid,double(obj.header.offset_to_point_data),-1);
        end

        obj.read_xyz();

        obj.extendedvariables = [];
        if isfield(obj.header,'number_of_extended_variable_length_record') ...
                && obj.header.number_of_extended_variable_length_record > 0 ...
                && ~feof(fid)
            fseek(fid,obj.header.start_of_extended_variable_length_record,-1);
            read_extended_variables(obj,fid);    
        end    

        fclose(fid);    

        if any(obj.header.point_data_format == [4 5])
            obj.wavedescriptors = obj.decode_waveform_packet_desc(obj.variablerecords);
            obj.setwaveformsource();
        end
    end    

    function obj = createemptyheader(obj)
            obj.header.source_id = [];
            obj.header.global_encoding = [];
            obj.header.project_id_guid1 = [];
            obj.header.project_id_guid2 = [];
            obj.header.project_id_guid3 = [];
            obj.header.project_id_guid4 = [];
            obj.header.version_major = [];
            obj.header.version_minor = [];
            obj.header.system_identifier = [];
            obj.header.generating_software = [];        
            obj.header.file_creation_daobj.y = [];
            obj.header.file_creation_year = [];
            obj.header.header_size = [];
            obj.header.offset_to_point_data = [];
            obj.header.number_of_variable_records = [];
            obj.header.point_data_format = [];
            obj.header.point_data_record_length = [];
            obj.header.number_of_point_records = [];
            obj.header.number_of_points_by_return = [];
            obj.header.scale_factor_x = [];         
            obj.header.scale_factor_y = [];         
            obj.header.scale_factor_z  = [];         
            obj.header.x_offset = [];         
            obj.header.y_offset = [];         
            obj.header.z_offset = [];
            obj.header.max_x = [];          
            obj.header.min_x = [];          
            obj.header.max_y = [];          
            obj.header.min_y = [];          
            obj.header.max_z  = [];          
            obj.header.min_z  = [];      
            obj.header.start_of_extended_variable_length_record = [];  
            obj.header.number_of_extended_variable_length_record = []; 
            obj.header.start_of_waveform_data = [];
    end    
    
    function obj = readheader(obj,fid)
        str = fscanf(fid,'%c',4);
        if strcmp('LASF',str)==0
            fclose(fid);
            error([file ' is not a LAS file.'])
        end

        try 
            obj.header.source_id = fread(fid,1,'uint16');
            obj.header.global_encoding = fread(fid,1,'uint16');
            obj.header.project_id_guid1 = fread(fid,1,'uint32');
            obj.header.project_id_guid2 = fread(fid,1,'uint16');
            obj.header.project_id_guid3 = fread(fid,1,'uint16');
            obj.header.project_id_guid4 = fread(fid,8,'int8');
            obj.header.version_major = fread(fid,1,'uint8');
            obj.header.version_minor = fread(fid,1,'uint8');
            obj.header.system_identifier = fscanf(fid,'%c',32);
            obj.header.generating_software = fscanf(fid,'%c',32);        
            obj.header.file_creation_daobj.y = fread(fid,1,'uint16');
            obj.header.file_creation_year = fread(fid,1,'uint16');
            obj.header.header_size = fread(fid,1,'uint16');
            obj.header.offset_to_point_data = fread(fid,1,'uint32');
            obj.header.number_of_variable_records = fread(fid,1,'uint32');
            obj.header.point_data_format = fread(fid,1,'uint8');
            obj.header.point_data_record_length = fread(fid,1,'uint16');
            obj.header.number_of_point_records = fread(fid,1,'uint32');
            obj.header.number_of_points_by_return = fread(fid,5,'uint32');
            obj.header.scale_factor_x = fread(fid,1,'double');         
            obj.header.scale_factor_y = fread(fid,1,'double');         
            obj.header.scale_factor_z  = fread(fid,1,'double');         
            obj.header.x_offset = fread(fid,1,'double');         
            obj.header.y_offset = fread(fid,1,'double');         
            obj.header.z_offset = fread(fid,1,'double');
            obj.header.max_x = fread(fid,1,'double');          
            obj.header.min_x = fread(fid,1,'double');          
            obj.header.max_y = fread(fid,1,'double');          
            obj.header.min_y = fread(fid,1,'double');          
            obj.header.max_z  = fread(fid,1,'double');          
            obj.header.min_z  = fread(fid,1,'double');          
            if obj.header.version_minor > 2 %1.3        
                obj.header.start_of_waveform_data = fread(fid,1,'uint64');
            end
             % add one EVLR for 1.3, if point format 4 or 5 and internal waveforms
            if obj.header.version_major == 1 && obj.header.version_minor == 3 ...
                    && bitand(obj.header.global_encoding,2) && ~bitand(obj.header.global_encoding,4)
                obj.header.number_of_extended_variable_length_record = 1;
            end
            if obj.header.version_minor > 3 %1.4       
                obj.header.start_of_extended_variable_length_record = fread(fid,1,'uint64');  
                obj.header.number_of_extended_variable_length_record = fread(fid,1,'uint32');
                %copy legacy values to show
                obj.header.legacy_number_of_point_records_READ_ONLY = obj.header.number_of_point_records;
                obj.header.number_of_point_records = fread(fid,1,'uint64');
                obj.header.legacy_number_of_points_by_return_READ_ONLY = obj.header.number_of_points_by_return;
                obj.header.number_of_points_by_return = fread(fid,15,'uint64');
            end        
        catch ex
            fclose(fid);
            disp('Error while processing header information.')
            throw(ex)
        end

        if obj.header.version_major > 1 || obj.header.version_minor > 4
            warning('Trying to parse unsupported LAS version.');
        end
    end

    function obj = writeheader(obj,fid)
        fseek(fid,0,-1);
        fprintf(fid,'LASF');

        fwrite(fid, obj.header.source_id,'uint16');
        fwrite(fid, obj.header.global_encoding,'uint16');
        fwrite(fid, obj.header.project_id_guid1,'uint32');
        fwrite(fid, obj.header.project_id_guid2,'uint16');
        fwrite(fid, obj.header.project_id_guid3,'uint16');
        fwrite(fid, obj.header.project_id_guid4,'int8');
        fwrite(fid, obj.header.version_major,'uint8');
        fwrite(fid, obj.header.version_minor,'uint8');
        tmp = obj.header.system_identifier;
        tmp = [tmp zeros(1,32-length(tmp),'uint8')];
        fprintf(fid, '%c',tmp);
        tmp = obj.header.generating_software;
        tmp = [tmp zeros(1,32-length(tmp),'uint8')];
        fprintf(fid, '%c', tmp);        
        fwrite(fid, obj.header.file_creation_daobj.y,'uint16');
        fwrite(fid, obj.header.file_creation_year,'uint16');
        fwrite(fid, obj.header.header_size,'uint16');
        fwrite(fid, obj.header.offset_to_point_data,'uint32');
        fwrite(fid, obj.header.number_of_variable_records,'uint32');
        fwrite(fid, obj.header.point_data_format,'uint8');
        fwrite(fid, obj.header.point_data_record_length,'uint16');
        if obj.header.number_of_point_records < 2^32 %if legacy compatible
            fwrite(fid, obj.header.number_of_point_records,'uint32');
        else
            fwrite(fid, 0,'uint32');
        end
        
        %add lecagy only if possible by pointcount limited by uint32
        if obj.header.number_of_point_records < 2^32 && ...
                (length(obj.header.number_of_points_by_return) == 15 && ...
                 all(obj.header.number_of_points_by_return(6:15)==0))
            tmpp = obj.header.number_of_points_by_return;
            if length(obj.header.number_of_points_by_return)==15
                tmpp = tmpp(1:5);
            end
                
            fwrite(fid, tmpp,'uint32');
        else
            fwrite(fid, zeros(5,1,'uint32'),'uint32');
        end
        fwrite(fid, obj.header.scale_factor_x,'double');         
        fwrite(fid, obj.header.scale_factor_y,'double');         
        fwrite(fid, obj.header.scale_factor_z,'double');         
        fwrite(fid, obj.header.x_offset,'double');         
        fwrite(fid, obj.header.y_offset,'double');         
        fwrite(fid, obj.header.z_offset,'double');
        fwrite(fid, obj.header.max_x,'double');          
        fwrite(fid, obj.header.min_x,'double');          
        fwrite(fid, obj.header.max_y,'double');          
        fwrite(fid, obj.header.min_y,'double');          
        fwrite(fid, obj.header.max_z,'double');          
        fwrite(fid, obj.header.min_z,'double');          
        if obj.header.version_minor > 2 %1.3
            if ~isfield(obj.header,'start_of_waveform_data')
                fwrite(fid, 0,'uint64');
            else
                fwrite(fid, obj.header.start_of_waveform_data,'uint64');
            end
        end
        if obj.header.version_minor > 3 %1.4
            if ~isfield(obj.header,'start_of_extended_variable_length_record')
                fwrite(fid, 0,'uint64');
            else            
                fwrite(fid, obj.header.start_of_extended_variable_length_record,'uint64');
            end
            
            if ~isfield(obj.header,'number_of_extended_variable_length_record')
                fwrite(fid, 0,'uint32');
            else            
                fwrite(fid, obj.header.number_of_extended_variable_length_record,'uint32');
            end  
            
            if ~isfield(obj.header,'number_of_point_records')
                fwrite(fid, 0,'uint64');
            else            
                fwrite(fid, obj.header.number_of_point_records,'uint64');
            end
            
            if ~isfield(obj.header,'number_of_points_by_return')
                fwrite(fid, 15,'uint64');
            else                  
                fwrite(fid, obj.header.number_of_points_by_return,'uint64');
            end
        end
        %write header length
        pos = ftell(fid);
        fseek(fid,94,-1);
        fwrite(fid,pos,'uint16');
        fseek(fid,pos,-1);
    end
    
    function obj = read_variable_records(obj,fid)
        for k=1:obj.header.number_of_variable_records
            obj.variablerecords(k).reserved = fread(fid,1,'*uint16');          
            obj.variablerecords(k).user_id = fscanf(fid,'%c',16); 
            obj.variablerecords(k).record_id = fread(fid,1,'*uint16');
            obj.variablerecords(k).record_length = fread(fid,1,'*uint16');          
            obj.variablerecords(k).description = fscanf(fid,'%c',32);
            obj.variablerecords(k).data = fread(fid,obj.variablerecords(k).record_length,'*uint8');
            obj.variablerecords(k).data_as_text = char(obj.variablerecords(k).data(:))';
        end
    end

    function obj = write_variable_records(obj,fid)
        for k=1:obj.header.number_of_variable_records
            if obj.header.version_major==1 && obj.header.version_minor == 0
                tmp = char([hex2dec('BB') hex2dec('AA')]); %write las 1.0 variable record start
                fwrite(fid,tmp,'uint8');
            end
            
            fwrite(fid,obj.variablerecords(k).reserved,'uint16');          
            tmp = obj.variablerecords(k).user_id;
            tmp = [tmp zeros(1,16-length(tmp))];
            fprintf(fid,'%c',tmp);
            fwrite(fid,obj.variablerecords(k).record_id,'uint16');
            fwrite(fid,length(obj.variablerecords(k).data),'uint16');          
            tmp = obj.variablerecords(k).description;
            tmp = [tmp zeros(1,32-length(tmp))];
            fprintf(fid,'%c',tmp);
            fwrite(fid,obj.variablerecords(k).data,'uint8');
        end
    end    
    
    function obj = read_extended_variables(obj,fid)
        for k=1:obj.header.number_of_extended_variable_length_record
            obj.extendedvariables(k).reserved = fread(fid,1,'*uint16');
            obj.extendedvariables(k).user_id = fread(fid,16,'*int8');
            obj.extendedvariables(k).record_id = fread(fid,1,'*uint16');
            obj.extendedvariables(k).record_length_after_obj_header = fread(fid,1,'*uint64');    
            obj.extendedvariables(k).description = fread(fid,32,'*int8');
            if isfield(obj.header,'start_of_waveform_data') && ftell(fid) == obj.header.start_of_waveform_data
                warning('Skipping waveform data while reading extended variables. Access waveforms with waveform reading function.');
                obj.extendedvariables(k).data = [];
            else
                obj.extendedvariables(k).data = fread(fid,obj.extendedvariables.record_length_after_obj_header,'*uint8');
            end
        end
    end

    function obj = write_extended_variables(obj,fid)
        if ~isfield(obj.header,'number_of_extended_variable_length_record')
            obj.header.number_of_extended_variable_length_record = 0;
        end
            
        for k=1:obj.header.number_of_extended_variable_length_record
             fwrite(fid,obj.extendedvariables(k).reserved,'uint16');
             fwrite(fid,obj.extendedvariables(k).user_id,'int8');
             fwrite(fid,obj.extendedvariables(k).record_id,'uint16');
             fwrite(fid,length(obj.extendedvariables(k).data),'uint64');    
             fwrite(fid,obj.extendedvariables(k).description,'int8');
             fwrite(fid,obj.extendedvariables(k).data,'uint8');
        end
    end    
    
    function obj = setwaveformsource(obj)
        %check if external waveform file
        if bitand(obj.header.global_encoding,4)
            [pathtmp,filetmp]=fileparts(obj.originalname);
            if isempty(pathtmp)
                pathtmp = pwd;
            end
            obj.waveformfile = [pathtmp '\\' filetmp '.wdp'];
            if ~exist(obj.waveformfile,'file')
                warning(['External waveform file ' obj.waveformfile ' not found!'])
                return;
            end
        else
            obj.waveformfile = obj.filename;
        end
    end
    
end
    
methods(Static,Access=public)

    %line to triangle converter for plotting
    function arr = FlattenTriangleArrayComponent(arr)
        arr = padarray(arr',2,'post');
        d = arr(:);
        arr = d;
        arr = arr + [0; d(1:end-1)];
        arr = arr(1:end-3) + [0; 0; d(4:end-2)];
    end    
    
    function [codes] = list_classification_codes(format,noprint)
        
        if format==1.0 || format==1.1 || format==1.2 || format==1.3 

            codes={ 'Created, never classified',...
                'Unclassified','Ground', 'Low Vegetation',...
                'Medium vegetation', 'High vegetation', 'Building',...
                'Low point (noise)','Model key-point (mass point)',...
                'Water','Reserved', 'Reserved', 'Overlap Points'};

            if ~exist('noprint','var')
                fprintf('\nPoint Record Types 0-5\n');            
                for k=1:length(codes)
                    fprintf('%d  %s\n',k-1,codes{k})
                end            
                fprintf('13-31 Reserved\n\n')
            end
            for k=13:31; codes{k} = 'Reserved'; end
        else
            codes = {'Created, never classified',...
                'Unclassified','Ground', 'Low Vegetation',...
                'Medium vegetation', 'High vegetation', 'Building',...
                'Low point (noise)','Reserved','Water',...
                'Rail', 'Road surface', 'Reserved',...
                'Wire - guard (Shield)','Wire - conductor (Phase)',...
                'Transmission tower','Wire-structure connector (insulator)',...
                'Bridge deck','High noise'};  
            
            if ~exist('noprint','var')
                fprintf('\nPoint record types 6-10\n');           
                for k=1:length(codes)
                    fprintf('%d  %s\n',k-1,codes{k})
                end            
                fprintf('19-63  Reserved\n')
                fprintf('64-255  User definable\n\n')
            end
            for k=13:31; codes{k} = 'Reserved'; end
            for k=64:255; codes{k} = 'User definable'; end
        end
    end
    
    %helper class not operating on class data
    function desc = decode_waveform_packet_desc(data)
        r=1;
        for k=1:length(data)
            if data(k).record_id >=100 && data(k).record_id < 356 %waveform record types
                desc(r).bits = typecast(data(k).data(1),'uint8');
                desc(r).compression = typecast(data(k).data(2),'uint8');
                desc(r).number_of_samples = typecast(data(k).data(3:6),'uint32');
                desc(r).temporal_sample_spacing = typecast(data(k).data(7:10),'uint32');
                desc(r).digitizer_gain = typecast(data(k).data(11:18),'double');
                desc(r).digitizer_offset = typecast(data(k).data(19:26),'double');
                r=r+1;
            end
        end
        if ~exist('desc','var')
            warning('Expecting waveform descriptors, but found none.')
            desc = [];
        end
    end    
    
    function columndatafwrite(fid,data,columnpos,rowlength)
        %fwrite with block read/write to have faster column writes
        BLOCKROWS = 20000;
        
        insertdatalen = length(typecast(data(1,:),'uint8'));
        for k=1:BLOCKROWS:size(data,1)
            pos = ftell(fid);
            bend = k+BLOCKROWS-1;
            if bend > size(data,1)
                bend = size(data,1);
            end            
            
            %find file size
            fseek(fid,0,1);
            filelen = ftell(fid);
            fseek(fid,pos,-1);
            %create empty space, because reading will fail otherwise
            %next column write will be faster
            if filelen < ftell(fid)+(bend-k+1)
                need_to_allocate = (bend-k+1)*rowlength - (filelen-pos);
                fwrite(fid,zeros(need_to_allocate,1,'uint8'));
            end
            fseek(fid,pos,-1);
            
            %read block to memory
            block = fread(fid,(bend-k+1)*rowlength,'*uint8');
            block = reshape(block,rowlength,[])';
            
            %add data in memory
            tmp = data(k:bend,:)';
            tmp = typecast(tmp(:),'uint8');
            tmp = reshape(tmp,insertdatalen,[])';
            block(:,columnpos+1:columnpos+insertdatalen) = tmp;
            block = block';
            %write block back to file
            fseek(fid,pos,-1);
            fwrite(fid,block(:));
        end
    end

end
end

