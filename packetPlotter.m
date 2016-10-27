classdef packetPlotter
    properties
        url
    end
    methods
        function packet_plotter_obj = packetPlotter(url)
            packet_plotter_obj.url = url;
            get_trace_route(packet_plotter_obj);
        end
        
        function [output, trace_array] = get_trace_route(obj)
            % plots packets
            % input: url as string
            % output:   0 if worked, pops up a graph
            %           1 if not

            disp('Getting hops...');

            if (ismac||isunix)
                [output, trace_array] = nixpp(obj);
            elseif (ispc)
                [output, trace_array]  = pcpp(obj);
            else
                error('Unrecognized system OS');
                output = 1;
            end

            if output == 1
                error('Error: traceroute failed');
            else
                packetPlotter.trace_graph(trace_array);
            end
        end

        function [output, trace_array] = nixpp(obj)
            % get trace data for mac/linux/all nix based systems
            % input: url as string
            % output:   0 if commanded executed successfully
            %           1 if not
            [status, cmdout] = unix(['traceroute ' obj.url]);

            % if unsucessful, return
            if status == 1
                output = 1;
                return;
            end

            % retrieve lines from traceroute command
            cmdout = strsplit(cmdout, '\n');
            cmdout(1)=[]; cmdout(length(cmdout))=[];
            for i = 1:length(cmdout)
                trace_array(i) = packetPlotter.make_hop_nix(char(cmdout(i)));
            end
            
            % successful
            output = 0;
        end

        function [output, hops] = pcpp(obj)
            % get trace data for pc systems
            % input: url as string
            % output:   0 if commanded executed successfully
            %           1 if not
            [status, cmdout] = dos(['tracert ' obj.url]);
            cmdout = strsplit(cmdout, ':\n');
            cmdout = cmdout(2);
            cmdout = cmdout{1,:};
            trace_array = strsplit(cmdout, '\n');
            
            % Cut out the first empty statement and last two statements that we do not need
            trace_array(1) = [];
            trace_array_length = length(trace_array);
            trace_array(trace_array_length) = [];
            trace_array(trace_array_length - 1) = [];
            
            for i = 1:length(trace_array)
                hops(i) = packetPlotter.make_hop_pc(trace_array(i));
            end
            output = status;
        end
    end
    methods (Static)
        function hop = make_hop_nix(charr)
            if regexp(charr, '* *')
                hop = packetPlotter.createHop('', '', 0);
                packet_loss = 1;
                return
            end
            packet_loss = 0;
            names = regexp(charr, '[0-9a-z-\.]*\.([a-z]{3})', 'match');
            names(length(names)+1)={''};
            name = char(names(1));
            ips = regexp(charr, '(?:[0-9]{1,3}\.){3}[0-9]{1,3}', 'match');
            ip = ips(1);
            l_trials = regexp(charr, '[0-9.]*(?= ms)', 'match');
            
            l_trials_num = zeros(1, length(l_trials));
            for i=1:length(l_trials)
                l_trials_num(i)=str2num(char(l_trials(i)));
            end
            avg_latency = mean(l_trials_num);
            hop = packetPlotter.createHop(name, ip, avg_latency);
        end
        
        function hopObj = make_hop_pc(hopLine)
            if regexp(char(hopLine), '\*[ ]*\*[ ]*\*')
                hopObj = packetPlotter.createHop('', '', 0);
                packet_loss = 1;
                return
            else
                packet_loss = 0;
            end
            hopLine = char(hopLine);
            
            trials = regexp(hopLine, '[0-9]*(?= ms)', 'match');
            trials_num = str2double(trials);
            avg = mean(trials_num);

            ips = regexp(hopLine, '(?:[0-9]{1,3}\.){3}[0-9]{1,3}', 'match');
            ip = char(ips(1));
            
            names = regexp(hopLine, '[a-zA-Z0-9\.-]*\.[a-z]{3}', 'match');
            names(length(names)+1) = {''};
            name = char(names(1));
            hopObj = packetPlotter.createHop(name, ip, avg, packet_loss);
        end
        
        function hopObj = createHop(name, ip, avg_latency)
            hopObj = struct('location_name', name, 'location_ip', ip, 'avg_latency', avg_latency);
        end

        function [output] = trace_graph(trace_array)
            % draws graph given trace data
            % input: trace data as 1D array of hop classes
            % output:   0 if worked
            %           1 if not worked
            webmap;
            
            [geo, geo_time] = packetPlotter.get_geo_structs(trace_array);
            % find unique hops
            [geo, geo_time] = packetPlotter.find_unique_hops(geo, geo_time);
            
            [max_latency_index, max_latency] = packetPlotter.find_max_latency_link(geo_time);
            [min_latency_index, min_latency] = packetPlotter.find_min_latency_link(geo_time);
            
            % done processing, drawing now
            color_map = packetPlotter.calculate_color_map(max_latency, min_latency);
            lastdrawn = [0.0 0.0];
            for i = 1:length(geo)
                lat = str2double(geo(i).lat);
                lon = str2double(geo(i).long);
                % get info to display in hop bubbles
                des = '';
                destination_location = '';
                if ~isempty(geo(i).country)
                    des = [des '<b>Country</b>: ' geo(i).country '<br>'];
                    destination_location = geo(i).country;
                end
                if ~isempty(geo(i).region)
                    des = [des '<b>Region</b>: ' geo(i).region '<br>'];
                    destination_location = [geo(i).region ', ' destination_location];
                end
                if ~isempty(geo(i).city)
                    des = [des '<b>City</b>: ' geo(i).city '<br>'];
                    destination_location = [geo(i).city ', ' destination_location];
                end
                
                locations{i} = destination_location;

                % draw marker
                feat = sprintf('Hop %s', int2str(i));
                wmmarker(lat, lon, 'Description', des, 'FeatureName', feat);
                
                % draw line
                if lastdrawn==[0.0 0.0]
                    lastdrawn = [lat lon];
                else
                    packetPlotter.draw_line(min_latency, geo_time, locations, i, lat, lon, lastdrawn, color_map);
                end
                lastdrawn = [lat lon];
            end
            output = 0;
            disp('Done');
            end
        
        
        function draw_line(min_latency, geo_time, locations, i, lat, lon, lastdrawn, color_map)
            if min_latency < 0
                min_latency = 0;
            end
            latency = packetPlotter.calculate_latency(geo_time, i);
            display_latency = num2str(latency);
            if latency < 0
                display_latency = '~0';
            end
            link_description = ['<b>Link latency</b>: ' display_latency ' ms' '<br>'];
            path_description = [locations{i - 1} ' to ' locations{i} '<br>'];


            color_value = packetPlotter.get_color_value(latency, min_latency);
            % draw line
            wmline([lat lastdrawn(1)], [lon lastdrawn(2)], 'Description', link_description, 'FeatureName', path_description, 'Color', color_map(color_value, :));
        end
        
        function [geo, geo_time] = get_geo_structs(trace_array)
            counter = 1;
            for i = 1:length(trace_array)
                if ~isempty(trace_array(i).location_ip)
                    geo(counter) = packetPlotter.geo_struct(trace_array(i).location_ip, i);
                    geo_time(counter) = trace_array(i).avg_latency;
                    counter = counter + 1;
                end
            end
        end
        
        function latency = calculate_latency(geo_time, i)
            latency = geo_time(i) - geo_time(i - 1);
        end
        
        function color_value = get_color_value(latency, min_latency)
            color_value = round((latency - min_latency) * 3); % handles the offset
            if color_value <= 0
                color_value = 1;
            end
        end
        
        function color_map = calculate_color_map(max_latency, min_latency)
            if min_latency < 0
                min_latency = 0;
            end
            range = max_latency - min_latency;
            range = round(range * 3);
            color_map = jet(range);
        end
        
        function [geo, geo_time] = find_unique_hops(geo, geo_time)
            hashofdrawn = [0.0];
            length_of_geo = length(geo);
            i = 1;
            while i <= length_of_geo
                
                %getting info
                lat = str2double(geo(i).lat);
                lon = str2double(geo(i).long);
                
                % check if need skip
                if any(hashofdrawn==(abs(lat+lon)))
                    geo(i) = [];
                    geo_time(i) = [];
                    length_of_geo = length_of_geo - 1;
                else
                    hashofdrawn = [hashofdrawn (abs(lat+lon))];
                    i = i + 1;
                end
                
            end
        end
        
        function [max_latency_index, max_latency] = find_max_latency_link(geo_times)
            max_latency_index = 1;
            max_difference = 0;
            i = 1;
            while i + 1 <= length(geo_times)
                if geo_times(i + 1) - geo_times(i) > max_difference
                    max_latency_index = i + 1;
                    max_difference = geo_times(i + 1) - geo_times(i);
                end
                i = i + 1;
            end 
            max_latency = max_difference;
        end
        
        function [min_latency_index, min_latency] = find_min_latency_link(geo_times)
            min_latency_index = 1;
            min_difference = intmax;
            i = 1;
            while i + 1 <= length(geo_times)
                if geo_times(i + 1) - geo_times(i) < min_difference
                    min_latency_index = i + 1;
                    min_difference = geo_times(i + 1) - geo_times(i);
                end
                i = i + 1;
            end 
            min_latency = min_difference;
        end
        
        function fake_json = geo_struct(ip, i)
            % Returns a struct containing city, region, country, lat, and long
            url = sprintf('http://freegeoip.net/json/%s', ip);
            json = urlread(url);

            ci_r = regexp(json, '(?<=city":")[^"]*', 'match', 'once');
            re_r = regexp(json, '(?<=region_name":")[^"]*', 'match', 'once');
            co_r = regexp(json, '(?<=country_name":")[^"]*', 'match', 'once');
            la_r = regexp(json, '(?<=latitude":)[^"]*', 'match', 'once');
            lo_r = regexp(json, '(?<=longitude":)[^"]*', 'match', 'once');

            fake_json = struct('city', ci_r, 'region', re_r, 'country', co_r, 'lat', la_r, 'long', lo_r);
            disp(['hop ' int2str(i) ' ' ip ' ' ci_r ' ' re_r ' ' co_r]);
        end
        
    end
end  