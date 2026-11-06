function set_data_size(block,name,sz)
%SET_DATA_SIZE Make bus-array orientation explicit at MATLAB Function boundaries.
ch=find(sfroot,'-isa','Stateflow.EMChart','Path',block);
d=find(ch,'-isa','Stateflow.Data','Name',name);d.Props.Array.Size=sz;
end
