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
                return
            end
            disp(charr)
            names = regexp(charr, '[0-9a-z-\.]*\.([a-z]{3})', 'match');
            names(length(names)+1)={''};
            name = char(names(1));
            ips = regexp(charr, '(?:[0-9]{1,3}\.){3}[0-9]{1,3}', 'match');
            ip = ips(1);
            l_trials = regexp(charr, '[0-9.]*(?= ms)', 'match');
            disp(l_trials)
            l_trials_num = zeros(1, length(l_trials));
            for i=1:length(l_trials)
                l_trials_num(i)=str2num(char(l_trials(i)));
            end
            avg_latency = mean(l_trials_num);
            hop = packetPlotter.createHop(name, ip, avg_latency);
        end
        
        function hopObj = make_hop_pc(hopLine)
%             disp(hopLine);
            if regexp(char(hopLine), '\*[ ]*\*[ ]*\*')
                hopObj = packetPlotter.createHop('', '', 0);
                return
            end
            hopLine = char(hopLine);
%             disp(hopLine);
            
            trials = regexp(hopLine, '[0-9]*(?= ms)', 'match');
%             disp(trials);
            trials_num = str2double(trials);
%             disp(trials_num);
            avg = mean(trials_num);
            
            %disp(avg);
            ips = regexp(hopLine, '(?:[0-9]{1,3}\.){3}[0-9]{1,3}', 'match');
            ip = char(ips(1));
            %disp(ip);
            %disp(length(ip));
            
            names = regexp(hopLine, '[a-zA-Z0-9\.-]*\.[a-z]{3}', 'match');
            names(length(names)+1) = {''};
            %disp(names(1));
            name = char(names(1));
            %disp(length(name));
            hopObj = packetPlotter.createHop(name, ip, avg);
        end
        
        function hopObj = createHop(name, ip, avg_latency)
            hopObj = struct('location_name', name, 'location_ip', ip, 'avg_latency', avg_latency);
        end

        function [output] = trace_graph(trace_array)
            % draws graph given trace data
            % input: trace data as 1D array of hop classes
            % output:   0 if worked
            %           1 if not worked
%             disp('got to trace_graph');
            webmap;
%             disp('ran trace_graph');
            counter = 1;
            for i = 1:length(trace_array)
                if ~isempty(trace_array(i).location_ip)
                    if counter>1
                        t1 = strsplit(trace_array(i-1).location_ip, '.');
                        t1 = t1(1);
                        t1 = t1{1,:};
                        t2 = strsplit(trace_array(i).location_ip, '.');
                        t2 = t2(1);
                        t2 = t2{1,:};
                        %disp(t1);
                        geo(counter) = packetPlotter.geo_struct(trace_array(i).location_ip, i);
                        geo_time(counter) = trace_array(i).avg_latency;
                        counter = counter + 1;
                    else
                        geo(counter) = packetPlotter.geo_struct(trace_array(i).location_ip, i);
                        geo_time(counter) = trace_array(i).avg_latency;
                        counter = counter + 1;
                    end
                end
            end
        
            max_latency_index = packetPlotter.find_max_latency_link(geo_time);
            disp(max_latency_index)
            
            % done processing, drawing now
            lastdrawn = [0.0 0.0];
            markedForSkip = false;
            hashofdrawn = [0.0];
            hopToDisplay = 1;
            disp(geo)
            disp(geo_time)
            color_map = redgreencmap(length(geo));
            
            
            for i= 1:length(geo)
                
                %getting info
                lat = str2double(geo(i).lat);
                lon = str2double(geo(i).long);
                
                % get info to display in hop bubbles
                des = '';
                if ~isempty(geo(i).city)
                    des = [des '<b>City</b>: ' geo(i).city '<br>'];
                end
                if ~isempty(geo(i).region)
                    des = [des '<b>Region</b>: ' geo(i).region '<br>'];
                end
                if ~isempty(geo(i).country)
                    des = [des '<b>Country</b>: ' geo(i).country '<br>'];
                end
                feat = sprintf('Hop %s', int2str(hopToDisplay));

                % check if need skip
                if any(hashofdrawn==(abs(lat+lon)))
                    markedForSkip = true;
                end
                
                % draw if not skip
                if ~markedForSkip
                    % draw marker
                    wmmarker(lat, lon, 'Description', des, 'FeatureName', feat);
                    % line stuff
                    if lastdrawn==[0.0 0.0]
                        lastdrawn = [lat lon];
                    else
                        if 0 == 1%i == max_latency_index
                            wmline([lat lastdrawn(1)], [lon lastdrawn(2)], 'Color', color_map(i, :));
                        else
                            disp(i)
                            wmline([lat lastdrawn(1)], [lon lastdrawn(2)], 'Color', color_map(i, :));
                        end
                        lastdrawn = [lat lon];
                    end
                    % mark as drawn
                    hashofdrawn = [hashofdrawn (abs(lat+lon))];
                    hopToDisplay = hopToDisplay+1;
                end
                
                % put skip marker back
                markedForSkip = false;
            end
    
            output = 0;
            disp('Done');
        end
        
        function max_latency_index = find_max_latency_link(geo_times)
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